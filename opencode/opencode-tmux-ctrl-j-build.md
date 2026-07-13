# Building opencode with the tmux Ctrl-J fix (patched opentui)

_Runbook written 2026-07-06. Companion to `opencode-tmux-ctrl-j-fix.md`, which
explains **why** the fix is needed (tmux + modifyOtherKeys level 1 delivers
Ctrl-J as a raw `0x0a` newline; level 2 encodes it distinctly). **This file is
the reproducible "how" — how to actually get a patched opentui running inside a
source checkout of opencode, from scratch, on a new machine.**_

Read the companion file first if you don't already know the root cause. Verified
on macOS arm64; written to also work on Linux (x64/arm64). Windows not covered.

---

## TL;DR (what the working setup actually is)

The entire fix lives in **one compiled native library** (`libopentui.{dylib,so}`),
not in any JavaScript. So the working approach is:

1. Check out **opentui at the exact version opencode pins** (a git *tag*, e.g.
   `v0.3.4`), and cherry-pick the one-line level-2 fix onto it.
2. Build **only the native library** from that source, using the **exact Zig
   version opentui requires** (0.3.4 needs Zig **0.15.2** — not whatever's newest).
3. **Copy that one built library file** over the prebuilt binary sitting in
   opencode's bun package store. On macOS, re-sign it ad-hoc.
4. Leave opencode's `package.json` **completely unchanged** (all `@opentui/*` stay
   `catalog:`). Do **not** use `bun link` / `link:` overrides — see the dead-ends
   section for why that breaks the TUI.

The tradeoff: the copied library is **wiped by any `bun install`** in opencode.
The `reapply` script at the bottom re-does steps 2–3 in one shot.

---

## Prerequisites

- Two source checkouts side by side (paths are examples — adjust to yours):
  - opencode: `~/Documents/Tech/opencode`
  - opentui:  `~/Documents/Tech/opentui`
- `bun` (opencode's package manager), `git`, `curl`, `tar`, `python3`.
- **Do not rely on a system-installed Zig.** opentui pins an exact Zig version and
  a newer one *will not build it* (0.16.0 fails on 0.15.2 source with
  `no field or member function named 'addIncludePath'` etc.). We fetch the pinned
  Zig into a local dir and never touch the system one.

---

## Step 0 — Find the two numbers everything depends on

Everything below is driven by two values. **Look them up; do not assume the ones
in this doc are still current** — opencode bumps its opentui pin over time.

### 0a. Which opentui version does opencode expect?

From the opencode repo root:

```sh
cd ~/Documents/Tech/opencode
python3 -c "import json;print(json.load(open('package.json'))['workspaces']['catalog']['@opentui/core'])"
# -> e.g. 0.3.4
```

Call this `$OTVER` (here: **0.3.4**). opencode resolves `@opentui/core`,
`@opentui/keymap`, `@opentui/solid` all at this version via its workspace
`catalog`. You must build the native lib from **this same version's source**, or
the JS and the native ABI can mismatch.

### 0b. Which Zig version does that opentui source require?

After checking out opentui at the tag (Step 1), read it from the source:

```sh
cd ~/Documents/Tech/opentui
grep -A2 SUPPORTED_ZIG_VERSIONS packages/core/src/zig/build.zig
# -> .{ .major = 0, .minor = 15, .patch = 2 },  => Zig 0.15.2
```

Call this `$ZIGVER` (here: **0.15.2**).

---

## Step 1 — Check out opentui at the pinned version + cherry-pick the fix

opencode wants a *released* opentui (a tag), so start from the tag, not `main`.
`main` drifts ahead (e.g. to 0.4.x) and its `@opentui/solid` ABI won't match the
0.3.4 JS opencode loads — that mismatch is what first surfaced as a broken TUI.

```sh
cd ~/Documents/Tech/opentui
git fetch --all --tags

# Base branch on the exact release opencode pins:
git checkout -B ctrl-j-fix "v$OTVER"        # e.g. v0.3.4
```

Now apply the fix. It is a **single character** in one Zig source file
(`packages/core/src/zig/ansi.zig`): `modifyOtherKeysSet` from `>4;1m` to `>4;2m`.

If you already have the fix as a commit on another branch, cherry-pick it:

```sh
git cherry-pick <fix-commit-sha>            # commit msg: "request modifyOtherKeys level 2 ..."
```

Otherwise just make the edit directly and commit:

```sh
# ansi.zig, ~line 392:
#   pub const modifyOtherKeysSet = "\x1b[>4;1m";   ->   "\x1b[>4;2m"
git commit -am "fix: request modifyOtherKeys level 2 for tmux Ctrl-J/K"
```

Verify the fix is present on the current checkout:

```sh
grep modifyOtherKeysSet packages/core/src/zig/ansi.zig
# EXPECT: pub const modifyOtherKeysSet = "\x1b[>4;2m";
```

> There may be a companion commit that adds parser tests for uppercase extended
> keys; it's not required for the fix to work, but cherry-pick it too if you have
> it.

---

## Step 2 — Get the exact Zig version (locally, not system-wide)

The download filename scheme is **`zig-<arch>-<os>-<version>.tar.xz`**.
(Note the order: arch first, then os. An older `zig-<os>-<arch>-...` guess 404s.)

- macOS arm64:  `zig-aarch64-macos-$ZIGVER.tar.xz`
- macOS x64:    `zig-x86_64-macos-$ZIGVER.tar.xz`
- Linux x64:    `zig-x86_64-linux-$ZIGVER.tar.xz`
- Linux arm64:  `zig-aarch64-linux-$ZIGVER.tar.xz`

```sh
ZIGVER=0.15.2      # = $ZIGVER from step 0b

# pick arch/os for this machine:
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  ZIGPKG="zig-aarch64-macos-$ZIGVER" ;;
  Darwin-x86_64) ZIGPKG="zig-x86_64-macos-$ZIGVER" ;;
  Linux-x86_64)  ZIGPKG="zig-x86_64-linux-$ZIGVER" ;;
  Linux-aarch64) ZIGPKG="zig-aarch64-linux-$ZIGVER" ;;
  *) echo "unhandled platform"; exit 1 ;;
esac

mkdir -p ~/.local/zig && cd ~/.local/zig
curl -fSL -o "$ZIGPKG.tar.xz" "https://ziglang.org/download/$ZIGVER/$ZIGPKG.tar.xz"
tar -xf "$ZIGPKG.tar.xz"
~/.local/zig/$ZIGPKG/zig version        # EXPECT: 0.15.2
```

> If `ziglang.org` is slow/down, the download page lists community mirrors; the
> filename is identical.

---

## Step 3 — Build the native library from the patched source

`build:native` runs `zig build`, then stages the resulting library into
opentui's *own* `node_modules/@opentui/core-<platform>-<arch>/`. We only care
about that one staged library file.

```sh
cd ~/Documents/Tech/opentui
bun install                                   # populates workspace deps

export PATH="$HOME/.local/zig/$ZIGPKG:$PATH"  # pinned Zig FIRST on PATH
zig version                                   # EXPECT: 0.15.2 (not the system one)

cd packages/core
bun run build:native                          # EXPECT: "Built: @opentui/core-<platform>-<arch>"
```

Locate the freshly built library (name is platform-specific: `.dylib` on macOS,
`.so` on Linux):

```sh
BUILT=$(find ~/Documents/Tech/opentui/packages/core/node_modules \
          -path "*core-*" \( -name "libopentui.dylib" -o -name "libopentui.so" \) | head -1)
echo "$BUILT"
```

Confirm it actually contains the level-2 sequence and **not** level-1:

```sh
python3 - "$BUILT" <<'PY'
import sys; d=open(sys.argv[1],'rb').read()
print("has >4;2m (level 2):", b"\x1b[>4;2m" in d)   # EXPECT True
print("has >4;1m (level 1):", b"\x1b[>4;1m" in d)   # EXPECT False
PY
```

---

## Step 4 — Overwrite opencode's prebuilt library with the patched one

opencode loads the native lib from **its own bun store**, at a path like:

```
node_modules/.bun/@opentui+core-<platform>-<arch>@<OTVER>/node_modules/@opentui/core-<platform>-<arch>/libopentui.{dylib,so}
```

Find it generically (don't hardcode the platform):

```sh
cd ~/Documents/Tech/opencode
STORE=$(find node_modules/.bun -path "*core-*" \
          \( -name "libopentui.dylib" -o -name "libopentui.so" \) \
          ! -name "*.orig" | head -1)
echo "$STORE"
```

Back up the original once (so you can revert without a reinstall), then copy:

```sh
[ -f "$STORE.orig" ] || cp "$STORE" "$STORE.orig"   # keep the pristine signed prebuilt
cp "$BUILT" "$STORE"
```

### macOS only — re-sign (Linux: skip this)

A modified/replaced `.dylib` has an invalid signature; macOS then **SIGKILLs**
the process on load (symptom: `bun dev` exits instantly, "terminated by signal
SIGKILL"). Re-sign ad-hoc:

```sh
codesign --remove-signature "$STORE" 2>/dev/null
codesign -s - "$STORE"
codesign -v "$STORE" && echo "signature OK"          # must exit 0
```

Linux has no equivalent step — the `.so` loads as-is.

**Leave opencode's `package.json` alone.** All `@opentui/*` entries stay
`catalog:`; there are no `link:` overrides. Confirm:

```sh
grep -A5 '"overrides"' ~/Documents/Tech/opencode/package.json | grep opentui
# EXPECT all three -> "catalog:"
```

---

## Step 5 — Verify end to end (inside tmux)

Run the dev TUI in a tmux pane with extended keys, capturing raw output:

```sh
cd ~/Documents/Tech/opencode
LOG=/tmp/oc-verify.raw; rm -f "$LOG"
tmux kill-session -t oc-verify 2>/dev/null
tmux new-session -d -s oc-verify -x 200 -y 50
tmux set-option -t oc-verify -g extended-keys always
tmux pipe-pane -t oc-verify -o "cat >> $LOG"
tmux send-keys -t oc-verify "cd packages/opencode && bun dev" Enter
sleep 8
```

Three things must all be true:

```sh
# (a) requests level 2, never level 1:
python3 -c "d=open('$LOG','rb').read();print('>4;2m:',b'\x1b[>4;2m' in d,'| >4;1m:',b'\x1b[>4;1m' in d)"
# EXPECT: >4;2m: True | >4;1m: False

# (b) TUI actually renders (no renderer crash):
grep -q "No renderer found" "$LOG" && echo "BROKEN (renderer)" || echo "renderer OK"
tmux capture-pane -t oc-verify -p | grep -vE '^\s*$' | head   # should show the opencode UI, not a stack trace

# (c) ctrl+j arrives as a DISTINCT sequence, not a raw newline:
tmux send-keys -t oc-verify C-j          # (into a context where you can see it, or use the standalone capture below)

tmux kill-session -t oc-verify 2>/dev/null
```

### Standalone key-byte proof (independent of opencode)

This confirms the pane itself now disambiguates Ctrl-J:

```sh
cat > /tmp/keycap.ts <<'EOF'
process.stdout.write("\x1b[>4;2m")
process.stdin.setRawMode(true); process.stdin.resume()
process.stdin.on("data", b => {
  process.stderr.write("BYTES: " + [...b].map(x=>x.toString(16).padStart(2,"0")).join(" ") + "\n")
  process.stdout.write("\x1b[>4;0m"); process.exit(0)
})
setTimeout(()=>{process.stdout.write("\x1b[>4;0m");process.exit(1)},5000)
EOF

tmux new-session -d -s keycap -x 120 -y 30
tmux set-option -t keycap -g extended-keys always
tmux send-keys -t keycap "bun /tmp/keycap.ts 2>/tmp/keycap.out" Enter
sleep 1.5; tmux send-keys -t keycap C-j; sleep 1.5
cat /tmp/keycap.out
tmux kill-session -t keycap 2>/dev/null
```

**PASS** = any of the level-2 encodings, e.g.:
- `BYTES: 1b 5b 32 37 3b 35 3b 31 30 36 7e`  = `\x1b[27;5;106~`  (CSI-`~` form), or
- `BYTES: 1b 5b 31 30 36 3b 35 75`           = `\x1b[106;5u`     (CSI-`u` form).

Both decode to `{ name: "j", ctrl: true }`. **FAIL** = `BYTES: 0a` (raw newline,
still level 1). Which of the two forms tmux emits varies by tmux build; opentui's
parser handles both (`packages/core/src/lib/parse.keypress.ts`, the
`CSI 27;mod;code~` regex and the CSI-u path).

---

## Dead-ends — do NOT do these (they were tried and failed)

- **`link:` / `bun link` overrides pointing opencode at the local opentui
  checkout.** This makes bun load `@opentui/solid` as **two separate module
  instances** — the app's copy and the one from opencode's `bunfig.toml`
  `preload = ["@opentui/solid/preload"]`. opentui's renderer is stored in a
  solid `createContext` object; two instances = two different context objects, so
  the provider sets one and `useRenderer` reads the other. Result: the TUI dies
  immediately with `Error: No renderer found` (thrown from
  `packages/solid/src/elements/hooks.ts`). Keeping the single published-version
  JS from the bun store and swapping only the native lib avoids this entirely.

- **Building against a newer system Zig.** opentui 0.3.4 requires Zig 0.15.2
  exactly. Zig 0.16.0 fails the build (stdlib API changes:
  `addIncludePath`/`linkFramework`/`linkSystemLibrary`/`modules.put` signatures).
  Always use the pinned version from a local dir.

- **Building opentui `main` instead of the pinned tag.** `main` is ahead of the
  version opencode pins; its native/JS ABI can mismatch the JS opencode loads.
  Always base on `v$OTVER`.

---

## Durability & re-applying

The patched library sits in opencode's `node_modules/.bun/...` and is **wiped by
any `bun install`** in opencode (the `.orig` backup is restored, i.e. level-1
returns). The JS-side setup (all `catalog:`) needs no maintenance.

After any `bun install` in opencode, re-run **Step 3 + Step 4** — or use this
script (adjust the two repo paths and `$ZIGVER`/`$ZIGPKG` at top):

```sh
#!/usr/bin/env bash
set -euo pipefail
OPENCODE=~/Documents/Tech/opencode
OPENTUI=~/Documents/Tech/opentui
ZIGVER=0.15.2
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  ZIGPKG="zig-aarch64-macos-$ZIGVER" ;;
  Darwin-x86_64) ZIGPKG="zig-x86_64-macos-$ZIGVER" ;;
  Linux-x86_64)  ZIGPKG="zig-x86_64-linux-$ZIGVER" ;;
  Linux-aarch64) ZIGPKG="zig-aarch64-linux-$ZIGVER" ;;
  *) echo "unhandled platform"; exit 1 ;;
esac

# 1) build native from the patched opentui checkout
export PATH="$HOME/.local/zig/$ZIGPKG:$PATH"
( cd "$OPENTUI/packages/core" && bun run build:native )
BUILT=$(find "$OPENTUI/packages/core/node_modules" -path "*core-*" \
          \( -name libopentui.dylib -o -name libopentui.so \) | head -1)

# 2) copy over opencode's store lib (+ re-sign on macOS)
STORE=$(find "$OPENCODE/node_modules/.bun" -path "*core-*" \
          \( -name libopentui.dylib -o -name libopentui.so \) ! -name "*.orig" | head -1)
[ -f "$STORE.orig" ] || cp "$STORE" "$STORE.orig"
cp "$BUILT" "$STORE"
if [ "$(uname -s)" = "Darwin" ]; then
  codesign --remove-signature "$STORE" 2>/dev/null || true
  codesign -s - "$STORE"
  codesign -v "$STORE"
fi

# 3) sanity check
python3 - "$STORE" <<'PY'
import sys; d=open(sys.argv[1],'rb').read()
assert b"\x1b[>4;2m" in d and b"\x1b[>4;1m" not in d, "level-2 patch NOT present in store lib"
print("OK: store lib is level-2 patched")
PY
echo "Done. Restart 'bun dev'."
```

**To revert** (drop back to the stock prebuilt library): `cp "$STORE.orig"
"$STORE"` (then re-sign on macOS), or just run `bun install` in opencode.

**The real long-term fix** is upstream: opentui shipping level-2 by default
(tracked as opentui issue #1184). Once that lands in a release and opencode bumps
its `@opentui/core` catalog pin to include it, this whole procedure is obsolete —
delete it.

---

## Caveat carried over from the analysis

`ctrl+m` still cannot be distinguished from `Enter` inside tmux at any
modifyOtherKeys level (both are ASCII 13). That's fundamental to tmux (no kitty
protocol support), not something this build fixes. Don't bind commands to
`ctrl+m` if you use tmux. See `opencode-tmux-ctrl-j-fix.md` for details.
