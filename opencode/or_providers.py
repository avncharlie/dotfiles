#!/usr/bin/env python3
"""
Rank OpenRouter hosting providers for GLM-5.2 / Kimi-K2.7-Code / DeepSeek-V4-Pro.

Reference = the model lab's OWN direct API price, fetched live from the lab's
pricing page (hardcoded fallback if the fetch/parse fails). Colours:
  price  : GREEN if <= reference (source), RED if more expensive ("out")
  uptime : GREEN >=99%, YELLOW 95-99%, RED <95%
  quant  : GREEN if == reference precision, RED if different, DIM if undisclosed
Colour auto-disables when piped (honours NO_COLOR; FORCE_COLOR=1 forces it on).

By default the script prints the usual CLI tables and then serves an interactive
web UI on localhost:8765. The UI reuses the same snapshot (no re-fetch on reload).
Use --cli-only to print to the terminal and exit.

No API key required.
  GET /api/v1/models/{author}/{slug}/endpoints  -> pricing, quant, uptime, params
  GET /api/v1/providers                          -> headquarters, datacenters
  https://openrouter.ai/<slug>                   -> p50 throughput/latency payload
"""
import http.server
import json, os, re, sys, urllib.request

BLEND = (3, 1)  # input:output weighting for the single blended $/M number

# label -> (openrouter slug, lab's own provider name, direct-pricing URL, reference quant)
MODELS = {
    "GLM-5.2":         ("z-ai/glm-5.2",              "Z.ai",        "https://docs.z.ai/guides/overview/pricing",           "fp8"),
    "Kimi-K2.7-Code":  ("moonshotai/kimi-k2.7-code", "Moonshot AI", "https://platform.kimi.ai/docs/pricing/chat-k27-code", "int4"),
    "DeepSeek-V4-Pro": ("deepseek/deepseek-v4-pro",  "DeepSeek",    "https://api-docs.deepseek.com/quick_start/pricing",    "fp8"),
}

# Direct API prices per 1M: (input_cache_miss, output, input_cache_hit).
# Verified against the lab pricing pages at time of writing; used if live fetch fails.
DIRECT_FALLBACK = {
    "GLM-5.2":         (1.40,  4.40,  0.26),
    "Kimi-K2.7-Code":  (0.95,  4.00,  0.19),
    "DeepSeek-V4-Pro": (0.435, 0.87,  0.003625),
}

COUNTRY = {
    "US":"United States","CN":"China","SG":"Singapore","FI":"Finland","SE":"Sweden",
    "ID":"Indonesia","GB":"United Kingdom","UK":"United Kingdom","DE":"Germany","FR":"France",
    "NL":"Netherlands","CA":"Canada","JP":"Japan","KR":"South Korea","IN":"India","AU":"Australia",
    "IE":"Ireland","CH":"Switzerland","HK":"Hong Kong","TW":"Taiwan","AE":"UAE","PL":"Poland",
    "NO":"Norway","ES":"Spain","IT":"Italy","BR":"Brazil","IL":"Israel","EU":"EU",
}
def country(code):
    if not code or code == "?": return "?"
    return ", ".join(COUNTRY.get(c.strip().upper(), c.strip()) for c in code.split(","))

# ---------------- colour ----------------
USE_COLOR = bool(os.environ.get("FORCE_COLOR")) or (
    sys.stdout.isatty() and os.environ.get("NO_COLOR") is None)
G, R, Y, DIM, RST = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"
def paint(s, c):
    return f"{c}{s}{RST}" if (USE_COLOR and c) else s
def cell(text, width, c=None, right=False):
    s = f"{text:>{width}}" if right else f"{text:<{width}}"
    return paint(s, c)

# ---------------- http ----------------
def _open(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (or_providers)"})
    return urllib.request.urlopen(req, timeout=30)
def get_json(url):
    return json.load(_open(url))["data"]

# ------------- direct-price scrapers (best effort; fall back to hardcoded) -------------
def fetch_raw(url):
    # docs.z.ai / platform.kimi.ai serve raw markdown when asked; Docusaurus (deepseek) returns HTML
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (or_providers)",
        "Accept": "text/markdown, text/plain, text/html"})
    return urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")

def parse_glm(t):
    m = re.search(r"GLM-5\.2\b([^\n]*)", t)
    if not m: return None
    nums = re.findall(r"\$\s*([0-9]+(?:\.[0-9]+)?)", m.group(1))  # input, cached, output (first 3)
    return (float(nums[0]), float(nums[2]), float(nums[1])) if len(nums) >= 3 else None

def parse_kimi(t):
    m = re.search(r'"kimi-k2\.7-code"\s*,([^\n]*)', t)  # leading quote avoids the -highspeed row
    if not m: return None
    nums = re.findall(r'(?:\{"\$"\}|\$)\s*([0-9]+(?:\.[0-9]+)?)', m.group(1))  # hit, miss, out
    return (float(nums[1]), float(nums[2]), float(nums[0])) if len(nums) >= 3 else None

def parse_deepseek(t):
    t = re.sub(r"<[^>]+>", " ", t)  # deepseek serves HTML (no JSX fragments, safe to strip)
    def grab(label):  # two columns (flash, pro); take the 2nd = pro
        m = re.search(label + r"[^\$]*\$\s*[0-9.]+\s*\$\s*([0-9]+(?:\.[0-9]+)?)", t)
        return float(m.group(1)) if m else None
    inn, out, hit = grab(r"CACHE MISS\)"), grab(r"OUTPUT TOKENS"), grab(r"CACHE HIT\)")
    return (inn, out, hit) if None not in (inn, out, hit) else None

PARSERS = {"GLM-5.2": parse_glm, "Kimi-K2.7-Code": parse_kimi, "DeepSeek-V4-Pro": parse_deepseek}

def direct_price(label, url):
    try:
        v = PARSERS[label](fetch_raw(url))
        if v and v[0] > 0 and v[1] > 0 and v[2] < v[0]:  # sanity: positive, cache-hit < input
            return v, "live"
    except Exception:
        pass
    return DIRECT_FALLBACK[label], "FALLBACK"

# ---------------- analysis ----------------
def blended(inn, out):
    return (inn * BLEND[0] + out * BLEND[1]) / sum(BLEND)
def up_color(u):
    if u is None: return None
    return G if u >= 99 else (Y if u >= 95 else R)
def thr_color(t):        # tokens/sec, higher is better (green >=40, yellow 20-40, red <20)
    if t is None: return None
    return G if t >= 40 else (Y if t >= 20 else R)
def lat_color(ms):       # p50 latency ms, lower is better
    if ms is None: return None
    return G if ms <= 1500 else (Y if ms <= 4000 else R)

def fetch_page_stats(slug):
    """OpenRouter inlines per-provider p50_throughput / p50_latency in the model page's
    RSC payload (no auth, just a browser UA). Returns {provider_lower: (tok_s, latency_ms)}."""
    try:
        req = urllib.request.Request("https://openrouter.ai/" + slug, headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:151.0) Gecko/20100101 Firefox/151.0",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"})
        html = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
    except Exception:
        return {}
    stats = {}
    for seg in re.split(r"provider_name", html)[1:]:   # one segment per endpoint
        nm  = re.match(r'[\\":]+([^\\"]+)', seg)                     # provider name (tolerates escaping)
        thr = re.search(r'p50_throughput[\\":]+([0-9.]+)', seg)      # base key ('_30_minutes' has '_' after, won't match)
        lat = re.search(r'p50_latency[\\":]+([0-9.]+)', seg)
        if nm and thr:
            key = nm.group(1).strip().lower()
            stats.setdefault(key, (float(thr.group(1)), float(lat.group(1)) if lat else None))
    return stats

def _class_for(c):
    """Map ANSI colour constants emitted by up/thr/lat helpers to CSS class names."""
    if c == G: return "good"
    if c == R: return "bad"
    if c == Y: return "warn"
    if c == DIM: return "dim"
    return ""

def _fmt(x, places=4):
    return f"{x:.{places}f}" if x is not None else "na"

def collect_model_data(label, slug, source, ref_quant, url, geo):
    (r_in, r_out, r_hit), origin = direct_price(label, url)
    r_blend = blended(r_in, r_out)
    stats = fetch_page_stats(slug)
    eps = get_json(f"https://openrouter.ai/api/v1/models/{slug}/endpoints")["endpoints"]
    rows = []
    for e in eps:
        p = e["pricing"]
        inn, out = float(p["prompt"]) * 1e6, float(p["completion"]) * 1e6
        cache = float(p.get("input_cache_read", 0)) * 1e6
        b = blended(inn, out)
        q = e.get("quantization") or "unknown"
        u = e.get("uptime_last_1d")
        tool = "y" if "tools" in e.get("supported_parameters", []) else "-"
        hq, dc = geo.get(e["provider_name"].lower(), ("?", "?"))
        th, la = stats.get(e["provider_name"].lower(), (None, None))
        rows.append({
            "provider": e["provider_name"],
            "quant": q,
            "quantClass": _class_for(G if q == ref_quant else (DIM if q in ("unknown", "?") else R)),
            "inn": inn,
            "innClass": _class_for(G if inn <= r_in + 1e-9 else R),
            "out": out,
            "outClass": _class_for(G if out <= r_out + 1e-9 else R),
            "cache": cache,
            "cacheClass": _class_for(G if cache <= r_hit + 1e-9 else R),
            "blend": b,
            "blendClass": _class_for(G if b <= r_blend + 1e-9 else R),
            "uptime": u,
            "uptimeText": f"{u:.1f}%" if u is not None else "na",
            "upClass": _class_for(up_color(u)),
            "tok": th,
            "tokText": f"{th:.0f}" if th is not None else "na",
            "thrClass": _class_for(thr_color(th)),
            "lat": la,
            "latText": f"{la/1000:.2f}s" if la is not None else "na",
            "latClass": _class_for(lat_color(la)),
            "tool": tool,
            "hq": country(hq),
            "dc": country(dc),
        })
    rows.sort(key=lambda r: (blended(r["inn"], r["out"]), r["provider"]))
    return {
        "label": label,
        "slug": slug,
        "refQuant": ref_quant,
        "refOrigin": origin,
        "ref": {
            "in": r_in,
            "out": r_out,
            "hit": r_hit,
            "blend": r_blend,
        },
        "statsOk": bool(stats),
        "rows": rows,
    }

def print_cli(model):
    r = model["ref"]
    r_in, r_out, r_hit, r_blend = r["in"], r["out"], r["hit"], r["blend"]
    label, ref_quant = model["label"], model["refQuant"]
    print("\n" + "=" * 139)
    print(f"{label}  ({model['slug']})")
    print(f"reference = direct {MODELS[label][1]} API [{model['refOrigin']}]:  in ${r_in:g}  out ${r_out:g}  "
          f"cache-hit ${r_hit:g}   blended ${r_blend:.4f}/M   ref quant {ref_quant}"
          + ("" if model["statsOk"] else "   [speed: page fetch failed]"))
    print("=" * 139)
    print(cell("provider", 22) + cell("quant", 8) + cell("in/M", 9, right=True)
          + cell("out/M", 9, right=True) + cell("cache/M", 10, right=True)
          + cell("blend/M", 10, right=True) + "  "
          + cell("up1d", 7, right=True) + "  " + cell("tok/s", 6, right=True) + "  "
          + cell("lat", 7, right=True) + "  " + cell("tool", 5)
          + cell("HQ", 16) + "datacenters")
    for row in model["rows"]:
        print(cell(row["provider"], 22)
              + cell(row["quant"], 8, {"good":G,"bad":R,"dim":DIM}.get(row["quantClass"]), right=False)
              + cell(f"{row['inn']:.4f}", 9, G if row['innClass']=='good' else R, right=True)
              + cell(f"{row['out']:.4f}", 9, G if row['outClass']=='good' else R, right=True)
              + cell(f"{row['cache']:.4f}", 10, G if row['cacheClass']=='good' else R, right=True)
              + cell(f"{row['blend']:.4f}", 10, G if row['blendClass']=='good' else R, right=True) + "  "
              + cell(row["uptimeText"], 7, up_color(row["uptime"]), right=True) + "  "
              + cell(row["tokText"], 6, thr_color(row["tok"]), right=True) + "  "
              + cell(row["latText"], 7, lat_color(row["lat"]), right=True) + "  "
              + cell(row["tool"], 5) + cell(row["hq"], 16) + row["dc"])

# ---------------- web UI ----------------
def build_html(models):
    data_json = json.dumps(models, separators=(",", ":"))
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OpenRouter Provider Comparison</title>
<style>
:root {{ color-scheme: dark; }}
html,body {{ margin:0; background:#0d1117; color:#c9d1d9; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }}
body {{ padding: 1rem 1.5rem 3rem; }}
h1 {{ font-size:1.2rem; margin:0 0 .5rem; }}
p {{ margin:.3rem 0; color:#8b949e; font-size:.85rem; }}
tabs {{ display:flex; gap:.25rem; margin:1rem 0 0; border-bottom:1px solid #30363d; }}
.tab {{ padding:.45rem .9rem; cursor:pointer; border-radius:.35rem .35rem 0 0; user-select:none; background:#161b22; border:1px solid transparent; border-bottom-color:#30363d; }}
.tab:hover {{ background:#21262d; }}
.tab.active {{ background:#23863611; border-color:#30363d #30363d #0d1117; color:#58a6ff; font-weight:600; }}
.panel {{ display:none; margin-top:.5rem; }}
.panel.active {{ display:block; }}
.filters {{ display:flex; flex-wrap:wrap; gap:.5rem; align-items:center; margin:.5rem 0; padding:.5rem; background:#161b22; border:1px solid #30363d; border-radius:.4rem; }}
.filters label {{ font-size:.78rem; color:#8b949e; display:flex; align-items:center; gap:.25rem; }}
.filters input, .filters select {{ background:#0d1117; color:#c9d1d9; border:1px solid #30363d; border-radius:.25rem; padding:.25rem .4rem; font-size:.8rem; }}
.filters input[type="number"] {{ width:4.5rem; }}
.filters input[type="text"] {{ width:9rem; }}
.table-wrap {{ overflow-x:auto; }}
table {{ border-collapse: collapse; width:100%; font-size:.82rem; }}
th, td {{ padding:.35rem .55rem; border-bottom:1px solid #21262d; white-space:nowrap; }}
th {{ position:sticky; top:0; background:#161b22; text-align:left; cursor:pointer; user-select:none; font-weight:600; color:#f0f6fc; z-index:1; }}
th:hover {{ background:#21262d; }}
td.num, th.num {{ text-align:right; font-variant-numeric: tabular-nums; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }}
td.loc, th.loc {{ text-align:left; }}
.sort-indicator {{ margin-left:.25rem; color:#8b949e; }}
.ref-row {{ background:rgba(56,139,253,0.08); font-weight:600; }}
.ref-note {{ font-size:.7rem; color:#8b949e; font-weight:normal; margin-left:.4rem; }}
.good {{ color:#3fb950; }}
.warn {{ color:#d29922; }}
.bad {{ color:#f85149; }}
.dim {{ color:#8b949e; }}
.empty {{ color:#8b949e; padding:1rem; }}
.footer {{ margin-top:2rem; color:#8b949e; font-size:.75rem; }}
</style>
</head>
<body>
<h1>OpenRouter Provider Comparison</h1>
<p>Green = against the model lab's direct API price. Columns are sortable; use the filters below each tab.</p>
<tabs id="tabs"></tabs>
<div id="panels"></div>
<div class="footer">Data is a snapshot from the run that started this server. Reloading does not re-fetch.</div>
<script id="data" type="application/json">{data_json}</script>
<script>
const DATA = JSON.parse(document.getElementById('data').textContent);
const COLS = [
  {{key:'provider', label:'provider', align:'left'}},
  {{key:'quant',    label:'quant',    align:'left'}},
  {{key:'inn',      label:'in/M',     align:'right', fmt: v => v.toFixed(4)}},
  {{key:'out',      label:'out/M',    align:'right', fmt: v => v.toFixed(4)}},
  {{key:'cache',    label:'cache/M',  align:'right', fmt: v => v.toFixed(4)}},
  {{key:'blend',    label:'blend/M',  align:'right', fmt: v => v.toFixed(4)}},
  {{key:'uptime',   label:'up1d',     align:'right', fmtText: r => r.uptimeText}},
  {{key:'tok',      label:'tok/s',    align:'right', fmtText: r => r.tokText}},
  {{key:'lat',      label:'lat',      align:'right', fmtText: r => r.latText}},
  {{key:'tool',     label:'tool',     align:'left'}},
  {{key:'hq',       label:'HQ',       align:'left'}},
  {{key:'dc',       label:'datacenters', align:'left'}},
];
const tabsEl = document.getElementById('tabs');
const panelsEl = document.getElementById('panels');
const state = {{}};

function fmtRef(m, k) {{
  const v = m.ref[k];
  return k === 'in' || k === 'out' || k === 'hit' ? v.toFixed(4) : v.toFixed(4);
}}

function init() {{
  DATA.forEach(m => {{
    state[m.label] = {{
      sortKey: 'blend',
      sortDir: 1, // 1 asc, -1 desc
      text: '',
      quant: 'all',
      hideOverPriced: false,
      refQuantOnly: false,
      toolsOnly: false,
      minTok: '',
      maxLat: '',
    }};
  }});
  DATA.forEach((m, i) => {{
    const tab = document.createElement('div');
    tab.className = 'tab' + (i === 0 ? ' active' : '');
    tab.textContent = m.label;
    tab.onclick = () => setTab(i);
    tabsEl.appendChild(tab);

    const panel = document.createElement('div');
    panel.className = 'panel' + (i === 0 ? ' active' : '');
    panel.dataset.idx = i;
    panel.innerHTML = `
      <div class="filters">
        <label>search<input type="text" class="f-text" placeholder="provider / HQ / DC"></label>
        <label>quant<select class="f-quant"><option value="all">all</option><option value="fp8">fp8</option><option value="fp4">fp4</option><option value="int4">int4</option><option value="unknown">unknown</option><option value="other">other</option></select></label>
        <label title="hide rows whose quantization is not the lab reference"><input type="checkbox" class="f-refquant"> ref quant only</label>
        <label title="only rows priced at or below the lab reference"><input type="checkbox" class="f-over"> hide over-priced</label>
        <label title="only endpoints that advertise function-calling / tools support"><input type="checkbox" class="f-tools"> tools only</label>
        <label>min tok/s<input type="number" class="f-mintok" step="1" min="0"></label>
        <label>max lat s<input type="number" class="f-maxlat" step="0.1" min="0"></label>
      </div>
      <div class="table-wrap"><table><thead></thead><tbody></tbody></table></div>
    `;
    panel.querySelector('.f-text').oninput = e => {{ state[m.label].text = e.target.value.toLowerCase(); render(i); }};
    panel.querySelector('.f-quant').onchange = e => {{ state[m.label].quant = e.target.value; render(i); }};
    panel.querySelector('.f-refquant').onchange = e => {{ state[m.label].refQuantOnly = e.target.checked; render(i); }};
    panel.querySelector('.f-over').onchange = e => {{ state[m.label].hideOverPriced = e.target.checked; render(i); }};
    panel.querySelector('.f-tools').onchange = e => {{ state[m.label].toolsOnly = e.target.checked; render(i); }};
    panel.querySelector('.f-mintok').oninput = e => {{ state[m.label].minTok = e.target.value; render(i); }};
    panel.querySelector('.f-maxlat').oninput = e => {{ state[m.label].maxLat = e.target.value; render(i); }};
    panelsEl.appendChild(panel);
  }});
  DATA.forEach((_, i) => render(i));
}}

function setTab(idx) {{
  [...tabsEl.children].forEach((t, i) => t.classList.toggle('active', i === idx));
  [...panelsEl.children].forEach((p, i) => p.classList.toggle('active', i === idx));
}}

function passes(m, st, r) {{
  if (st.text && !r.provider.toLowerCase().includes(st.text) && !r.hq.toLowerCase().includes(st.text) && !r.dc.toLowerCase().includes(st.text)) return false;
  if (st.quant !== 'all') {{
    if (st.quant === 'unknown') {{ if (r.quant !== 'unknown') return false; }}
    else if (st.quant === 'other') {{ if (['fp8','fp4','int4','unknown'].includes(r.quant)) return false; }}
    else {{ if (r.quant !== st.quant) return false; }}
  }}
  if (st.refQuantOnly && r.quant !== m.refQuant) return false;
  if (st.hideOverPriced && (r.innClass !== 'good' || r.outClass !== 'good' || r.cacheClass !== 'good')) return false;
  if (st.toolsOnly && r.tool !== 'y') return false;
  if (st.minTok !== '' && (r.tok === null || r.tok < parseFloat(st.minTok))) return false;
  if (st.maxLat !== '' && (r.lat === null || (r.lat/1000) > parseFloat(st.maxLat))) return false;
  return true;
}}

function sortFn(st) {{
  const k = st.sortKey;
  return (a, b) => {{
    let av = a[k], bv = b[k];
    if (av === null) av = -Infinity;
    if (bv === null) bv = -Infinity;
    if (typeof av === 'string') av = av.toLowerCase();
    if (typeof bv === 'string') bv = bv.toLowerCase();
    if (av < bv) return -1 * st.sortDir;
    if (av > bv) return 1 * st.sortDir;
    return 0;
  }};
}}

function render(idx) {{
  const m = DATA[idx];
  const st = state[m.label];
  const panel = panelsEl.children[idx];
  const thead = panel.querySelector('thead');
  const tbody = panel.querySelector('tbody');
  tbody.innerHTML = '';

  // header
  const htr = document.createElement('tr');
  for (const col of COLS) {{
    const th = document.createElement('th');
    th.className = col.align === 'right' ? 'num' : 'loc';
    th.textContent = col.label;
    const ind = document.createElement('span');
    ind.className = 'sort-indicator';
    if (st.sortKey === col.key) ind.textContent = st.sortDir === 1 ? '▲' : '▼';
    th.appendChild(ind);
    th.onclick = () => {{
      state[m.label].sortKey = col.key;
      state[m.label].sortDir = (st.sortKey === col.key) ? -st.sortDir : 1;
      render(idx);
    }};
    htr.appendChild(th);
  }}
  thead.innerHTML = '';
  thead.appendChild(htr);

  // reference row (static, not sortable/filterable)
  const refTr = document.createElement('tr');
  refTr.className = 'ref-row';
  const refCols = [
    `<td><span style="color:#58a6ff">reference</span>` + (m.statsOk ? '' : '<span class="ref-note">[speed fetch failed]</span>') + `</td>`,
    `<td class="loc">${{m.refQuant}}</td>`,
    `<td class="num">${{fmtRef(m,'in')}}</td>`,
    `<td class="num">${{fmtRef(m,'out')}}</td>`,
    `<td class="num">${{fmtRef(m,'hit')}}</td>`,
    `<td class="num">${{fmtRef(m,'blend')}}</td>`,
    `<td colspan="6" style="color:#8b949e;font-weight:normal">lab direct API (origin: ${{m.refOrigin}})</td>`,
  ];
  refTr.innerHTML = refCols.join('');

  const filtered = m.rows.filter(r => passes(m, st, r));
  filtered.sort(sortFn(st));

  tbody.appendChild(refTr);
  if (filtered.length === 0) {{
    const empty = document.createElement('tr');
    empty.innerHTML = `<td colspan="${{COLS.length}}" class="empty">no providers match the current filters</td>`;
    tbody.appendChild(empty);
    return;
  }}

  for (const r of filtered) {{
    const tr = document.createElement('tr');
    for (const col of COLS) {{
      const td = document.createElement('td');
      td.className = col.align === 'right' ? 'num' : 'loc';
      if (col.key === 'provider' && r[col.key] === 'reference') td.innerHTML = r[col.key];
      else td.textContent = col.fmtText ? col.fmtText(r) : (col.fmt ? col.fmt(r[col.key]) : r[col.key]);
      const clsKey = col.key + 'Class';
      if (r[clsKey]) td.classList.add(r[clsKey]);
      tr.appendChild(td);
    }}
    tbody.appendChild(tr);
  }}
}}

init();
</script>
</body>
</html>
"""

def serve(html, port=8765):
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/":
                self.send_error(404)
                return
            body = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def log_message(self, format, *args): pass
    try:
        server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    except OSError as e:
        print(f"error: cannot bind web UI to port {port}: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"\nserving web UI at http://localhost:{port}/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped.", file=sys.stderr)

# ---------------- main ----------------
def _parse_port(args):
    for i, a in enumerate(args):
        if a == "--port" and i + 1 < len(args):
            try:
                return int(args[i + 1])
            except ValueError:
                print(f"warning: invalid --port value '{args[i+1]}', using 8765", file=sys.stderr)
    return 8765

def main(argv=None):
    args = argv if argv is not None else sys.argv[1:]
    cli_only = "--cli-only" in args
    port = _parse_port(args)
    geo = {}
    for pr in get_json("https://openrouter.ai/api/v1/providers"):
        geo[pr["name"].lower()] = (pr.get("headquarters") or "?",
                                    ",".join(pr.get("datacenters") or []) or "?")
    models = []
    for label, (slug, src, url, rq) in MODELS.items():
        model = collect_model_data(label, slug, src, rq, url, geo)
        print_cli(model)
        models.append(model)
    if cli_only:
        return
    serve(build_html(models), port=port)

if __name__ == "__main__":
    main()
