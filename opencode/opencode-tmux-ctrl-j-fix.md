# Ctrl-J / Ctrl-K keybinds don't work in opencode inside tmux

_Written up 2026-07-02. Environment: macOS (arm64), Alacritty, tmux 3.5a, opencode
1.17.13 (installed) + dev build from source, `@opentui/core` 0.3.4._

## TL;DR

- **Symptom:** In opencode's TUI, `ctrl+j` / `ctrl+k` bound to dialog navigation
  work in a bare terminal but do nothing inside tmux (ctrl+j just inserts a
  newline). Neovim binds the same keys fine inside the same tmux.
- **Root cause:** opencode's renderer (`@opentui/core`) falls back to xterm
  **modifyOtherKeys level 1** when the kitty keyboard protocol isn't available
  (which is always the case under tmux). Level 1 does **not** encode standard
  control keys like Ctrl-J, so tmux delivers a raw `0x0a` byte that is
  indistinguishable from a newline. Neovim works because it uses
  **modifyOtherKeys level 2**.
- **Fix:** force opentui to request modifyOtherKeys **level 2** (`CSI > 4 ; 2 m`)
  instead of level 1 (`CSI > 4 ; 1 m`). In the compiled native library this is a
  1-byte patch. After the change, tmux encodes `ctrl+j` as `\x1b[106;5u`
  (CSI-u), which opentui parses correctly as `{ name: "j", ctrl: true }`.
- **Not fixable this way:** `ctrl+m` inside tmux. Ctrl-M and Enter share ASCII
  13 (`\r`); tmux + modifyOtherKeys never disambiguate them. Only the full kitty
  protocol (which tmux does not support) can, so `ctrl+m` bindings are a lost
  cause inside tmux. Use a different key.

---

## Symptom

`~/.config/opencode/tui.json` contained:

```jsonc
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "editor_open": "ctrl+g",
    "session_list": "ctrl+l",
    "model_list": "ctrl+m",
    "dialog.select.prev": "up,ctrl+k",
    "dialog.select.next": "down,ctrl+j"
  }
}
```

- Outside tmux (bare Alacritty): `ctrl+j` / `ctrl+k` navigate dialogs correctly.
- Inside tmux: `ctrl+j` registers as a newline; `ctrl+k` does nothing.
- Neovim inside the *same* tmux distinguishes `ctrl+j` without issue.

The obvious question: "if neovim can do it in tmux, why can't opencode?"

---

## Background: how terminals send Ctrl-J

`Ctrl-J` is ASCII **Line Feed** (`0x0a`, `\n`). `Enter` is Carriage Return
(`0x0d`, `\r`). In a raw terminal with no enhanced keyboard protocol, an app
just sees these bytes and cannot tell `Ctrl-J` apart from a literal newline, nor
`Ctrl-M` apart from `Enter`.

Two protocols let a terminal disambiguate these:

1. **Kitty keyboard protocol** (progressive enhancement). App pushes
   `CSI > flags u` (e.g. `\x1b[>1u`). Keys then arrive CSI-u encoded, e.g.
   `Ctrl-J` = `\x1b[106;5u` (codepoint 106 = 'j', modifier `5` = `1 + 4`, where
   `4` = ctrl). This is what modern terminals + neovim negotiate.
2. **xterm modifyOtherKeys**. App enables with `CSI > 4 ; N m`:
   - **Level 1** (`>4;1m`): encodes only "other" keys, **not** standard control
     keys like Ctrl-J. Ctrl-J still arrives as raw `0x0a`.
   - **Level 2** (`>4;2m`): encodes control keys too. Ctrl-J arrives as
     `\x1b[106;5u`.

**Crucial fact about tmux 3.5a:** it does **not** implement the kitty keyboard
protocol. With `set -g extended-keys always` it *does* support and translate
modifyOtherKeys into CSI-u encoding for the pane — but only at the level the
app requests.

---

## Investigation

### 1. Confirmed opencode's config is not the problem

`packages/tui/src/app.tsx` creates the renderer with `useKittyKeyboard: {}`.
Initially this looked like the culprit — GitHub issue
[#4997](https://github.com/anomalyco/opencode/issues/4997) discusses the
`useKittyKeyboard: true → {} → false` history and the ctrl+m breakage. Flipping
it to `useKittyKeyboard: { events: true }` (the fix another user, `ariane-emory`,
reported in that thread) did **not** help inside tmux. Reverted.

`buildKittyKeyboardFlags` in the opentui JS shows `{}` already implies
`disambiguate: true` + `alternateKeys: true` (non-zero flags); `{ events: true }`
only adds event reporting. Neither controls the modifyOtherKeys *level*.

### 2. Captured the raw bytes tmux actually delivers

A small raw-mode capture script (`/tmp/keycap.ts`) that enables a chosen
protocol then prints incoming bytes. Pressing `ctrl+j`, `ctrl+k`, `Enter`,
`ctrl+m`:

**Outside tmux (kitty flags, `TERM=xterm-256color`):**

```
ctrl+j -> 1b 5b 31 30 36 3b 35 75   "\u001b[106;5u"
ctrl+k -> 1b 5b 31 30 37 3b 35 75   "\u001b[107;5u"
Enter  -> 0d
ctrl+m -> 1b 5b 31 30 39 3b 35 75   "\u001b[109;5u"
```

All distinct. 

**Inside tmux, kitty flags (`>7u`, `TERM=tmux-256color`):**

```
ctrl+j -> 0a   "\n"
ctrl+k -> 0b
Enter  -> 0d
ctrl+m -> 0d
```

Kitty ignored entirely (proves tmux has no kitty support — the pushed
`\x1b[>7u` was swallowed).

**Inside tmux, modifyOtherKeys level 1 (`>4;1m`):**

```
ctrl+j -> 0a   (still raw newline!)
ctrl+k -> 0b
```

Level 1 does not encode control keys — this is what opentui uses, hence the bug.

**Inside tmux, modifyOtherKeys level 2 (`>4;2m`):**

```
ctrl+j -> 1b 5b 31 30 36 3b 35 75   "\u001b[106;5u"   <- DISTINCT!
ctrl+k -> 1b 5b 31 30 37 3b 35 75   "\u001b[107;5u"   <- DISTINCT!
Enter  -> 0d
ctrl+m -> 0d                                          <- still same as Enter
```

**This is the answer.** Level 2 makes tmux disambiguate Ctrl-J/Ctrl-K. Ctrl-M
stays ambiguous with Enter (see caveat below).

### 3. Located what opentui emits

`@opentui/core` 0.3.4's native library
(`.../@opentui/core-darwin-arm64/libopentui.dylib`) contains, as static strings:

```
\x1b[?u      (kitty capability query)
\x1b[>u      (kitty push template; flags inserted at runtime)
\x1b[<u      (kitty pop)
\x1b[>4;1m   (modifyOtherKeys ON  — level 1)
\x1b[>4;0m   (modifyOtherKeys OFF)
Ptmux;       (tmux passthrough DCS wrapper)
```

Note: `\x1b[>4;2m` (level 2) is **not present anywhere** — opentui only ever
requests level 1. The `TerminalMultiplexer` enum (`none/tmux/zellij/screen`)
confirms it detects tmux, but it still only falls back to level-1
modifyOtherKeys.

Capturing the running dev TUI's startup output inside tmux confirmed the emitted
order: `\x1b[?u` (kitty query, unanswered under tmux) then `\x1b[>4;1m`
(level-1 fallback), and no kitty push. Hence: level-1 only → Ctrl-J = raw `0a`.

### 4. Confirmed opentui *parses* CSI-u correctly

The JS parser does `fromKittyMods(modifierMask - 1)` where `& 4` = ctrl. So an
incoming `\x1b[106;5u` (mod `5` → `4` → ctrl) decodes to `{ name: "j",
ctrl: true }`. The parser was never the problem — only the *level requested*.

---

## The fix

Change opentui's modifyOtherKeys request from level 1 to level 2. Since the
sequence lives as a static string in the compiled native library, this is a
single-byte patch (`'1'` → `'2'`), same length, in place.

Target file:

```
node_modules/.bun/@opentui+core-darwin-arm64@0.3.4/node_modules/@opentui/core-darwin-arm64/libopentui.dylib
```

Patch script (idempotent-ish, asserts before writing):

```python
import re
p = ".../@opentui/core-darwin-arm64/libopentui.dylib"
data = bytearray(open(p, "rb").read())
seq = b"\x1b[>4;1m"                     # ESC [ > 4 ; 1 m
off = data.index(seq)                   # single occurrence
assert data[off + 5] == 0x31            # the '1'
data[off + 5] = 0x32                    # -> '2'
open(p, "wb").write(data)
```

### macOS gotcha: re-sign after patching

Modifying the dylib invalidates its code signature. macOS then kills the process
with **SIGKILL** immediately on load (symptom: `bun dev` exits instantly with
`script "dev" was terminated by signal SIGKILL`). Re-sign ad-hoc:

```sh
codesign --remove-signature libopentui.dylib
codesign -s - libopentui.dylib
codesign -v libopentui.dylib      # should exit 0
```

### Verification

After patch + re-sign, the running TUI emits `\x1b[>4;2m` at startup, and a
temporary key logger (`keymap.intercept("key", ...)` appended to
`/tmp/opencode-keys.log`) confirmed real key events inside tmux:

```json
{"name":"j","ctrl":true,"shift":false,"meta":false,"raw":"\u001b[106;5u"}
{"name":"k","ctrl":true,"shift":false,"meta":false,"raw":"\u001b[107;5u"}
```

`ctrl+j` / `ctrl+k` navigation now works inside tmux. 

---

## Caveat: Ctrl-M cannot work inside tmux

`ctrl+m` never produced a distinct event (it logged as `return`). This is
fundamental, not a bug in our fix: Ctrl-M and Enter both are ASCII 13 (`\r`).
tmux + modifyOtherKeys (any level) does not disambiguate them; only the full
kitty protocol with escape-code disambiguation reports Enter separately as
`\x1b[13u`, and tmux does not support kitty. This matches the upstream
"cannot bind commands to ctrl+m" regression
([#5342](https://github.com/anomalyco/opencode/issues/5342)).

**Recommendation:** don't bind anything to `ctrl+m` if you use tmux. Rebind
`model_list` to e.g. `ctrl+o` or keep the default `<leader>m`.

---

## Durability / caveats

- The dylib patch lives in `node_modules` and is **wiped by any `bun install`**.
  It also only affects the dev build running from the source checkout, not the
  installed `~/.opencode/bin/opencode`.
- A backup of the original is at `libopentui.dylib.orig` (restore + it already
  has a valid original signature).

### Making it durable

Options, roughly in order of preference:

1. **Upstream fix (best).** This is tracked upstream as opentui issue
   [#1184 — "`modifyOtherKeys` mode should be 2 instead of 1"](https://github.com/anomalyco/opentui/issues/1184).
   The proposed fix is the one-character source change in
   `packages/core/src/zig/ansi.zig:394`:
   ```zig
   pub const modifyOtherKeysSet = "\x1b[>4;1m";   // -> "\x1b[>4;2m"
   ```
   Our dylib patch is byte-for-byte what that issue asks for. Once #1184 lands
   in opentui and opencode bumps its `@opentui/core` catalog pin, no more
   node_modules patching is needed. (Issue still open as of 2026-07-02: no PR,
   no labels, no assignee.)
2. **postinstall patch script.** A repo script that re-applies the byte patch +
   re-signs after every `bun install`. Fragile across opentui version bumps
   (offset / packaging changes) but self-contained.
3. **tmux-side workaround.** None found — tmux cannot be made to emit level-2
   encoding for an app that only requests level 1.

---

## Reference: key sequences

| Key    | Bare terminal (kitty) | tmux + mok level 1 | tmux + mok level 2 |
|--------|-----------------------|--------------------|--------------------|
| Ctrl-J | `\x1b[106;5u`         | `0a` (newline)     | `\x1b[106;5u`      |
| Ctrl-K | `\x1b[107;5u`         | `0b`               | `\x1b[107;5u`      |
| Ctrl-M | `\x1b[109;5u`         | `0d` (= Enter)     | `0d` (= Enter)     |
| Enter  | `0d`                  | `0d`               | `0d`               |

Modifier encoding (kitty/CSI-u): reported value = `1 + bitmask`, where
`1`=shift, `2`=alt, `4`=ctrl, `8`=super. So `;5u` = `1 + 4` = Ctrl.

## Relevant source locations

- `packages/tui/src/app.tsx` — `createCliRenderer({ useKittyKeyboard: {} ... })`
  (renderer setup; `useKittyKeyboard` does **not** control the mok level).
- `packages/tui/src/config/keybind.ts` — default keybinds; note
  `input_newline` defaults include `ctrl+j`, and `model_list` default is
  `<leader>m`.
- `packages/tui/src/ui/dialog-select.tsx` — `dialog.select.*` bindings.
- `@opentui/core` native lib — emits `\x1b[>4;1m`; the actual thing to change.
