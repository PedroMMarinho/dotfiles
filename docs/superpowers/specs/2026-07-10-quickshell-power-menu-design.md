# Quickshell Power Menu — Design

**Date:** 2026-07-10
**Status:** Approved (pending spec review)

## Purpose

A Wlogout-style power menu rendered by Quickshell, offering five session
actions — **Lock, Logout, Suspend, Reboot, Shutdown** — as a centered
horizontal row of buttons over a dimmed fullscreen backdrop. Opened with a
Hyprland keybind (`mod + X`) via Quickshell IPC.

It replaces the currently commented-out `mod + X -> Wlogout.sh` binding, giving
a native, theme-consistent power menu instead of the external `wlogout` tool.

## Architecture

Mirrors the existing `launcher/` module exactly. New folder `quickshell/power/`:

```
quickshell/power/
├── Controller.qml   # Singleton: isOpen + IpcHandler(target:"power") + LazyLoader → Overlay
└── Overlay.qml      # PanelWindow: dimmed fullscreen, exclusive keyboard, row of 5 buttons
```

### Controller.qml (singleton)

Copies the launcher's `Controller.qml` shape, minus the history manager:

- `property bool isOpen: false`
- `IpcHandler { target: "power"; function open()/close()/toggle() }`
- `LazyLoader { active: root.isOpen; Overlay { controller: root } }`
- `function init() {}` — called from `shell.qml`

### Overlay.qml

- `PanelWindow` anchored to all four edges (fullscreen), `exclusionMode: ExclusionMode.Ignore`.
- `color: "#35000000"` — same dim as the launcher backdrop.
- `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`, `WlrLayershell.namespace: "shell:power"`.
- A `MouseArea` filling the backdrop closes the menu on click (click-outside-to-cancel).
- A centered `Row` of 5 button items, each an `Item`/`Rectangle` + `MouseArea`
  containing a Nerd Font glyph above a text label.
- The `Row` itself sits in a container that stops backdrop clicks from closing
  when clicking a button.

## The five actions

Defined as a single JS array/model in `Overlay.qml`, iterated with `Repeater`.
Left → right:

| Index | Action    | Glyph | Mnemonic | Command                    |
|-------|-----------|-------|----------|----------------------------|
| 0     | Lock      | ``   | `l`      | `loginctl lock-session`    |
| 1     | Logout    | ``   | `e`      | `hyprctl dispatch exit`    |
| 2     | Suspend   | ``   | `s`      | `systemctl suspend`        |
| 3     | Reboot    | ``   | `r`      | `systemctl reboot`         |
| 4     | Shutdown  | ``   | `p`      | `systemctl poweroff`       |

- **Lock** uses `loginctl lock-session` for consistency with the existing setup
  (`hypridle.conf` and `LockScreen.sh` both lock this way; `hyprlock` is not in
  PATH, and `loginctl lock-session` triggers hypridle's `lock_cmd`).
- **Logout** uses `hyprctl dispatch exit` to exit the Hyprland session.
- Each command is a fixed argv passed to `Quickshell.execDetached({ command: [...] })`.
  No shell string interpolation — argv arrays only.

## Interaction

- Opens with keyboard focus grabbed. Initial selected index: 0 (Lock).
- **Left / Right arrows** move the selection between buttons (no wrap-around, or
  wrap — implementer's choice, default: wrap).
- **Enter / Return** activates the selected button.
- **Number keys 1–5** activate that button directly (1 = Lock … 5 = Shutdown).
- **Mnemonic letters** `l e s r p` activate the corresponding action directly
  (letters are direct-activate only; they do NOT move selection — arrows own movement).
- **Esc** closes the menu without acting.
- **Mouse:** hover highlights a button; click activates it; click on the dim
  backdrop (outside any button) closes without acting.
- Any activation runs the command via `Quickshell.execDetached`, then sets
  `controller.isOpen = false`.

## Theming

Colors come from `Theme.get` (the active theme `Item`). Add new Wlogout-specific
properties to **both** theme variants in `Theme.qml` (`windowsXP` and
`black_flat`) so switching themes stays consistent. Proposed new properties
(commented `// Wlogout power menu` in the file):

- `wlogoutButtonBg`         — idle button fill
- `wlogoutButtonBgHover`    — hovered/selected button fill
- `wlogoutBorderColor`      — idle button border
- `wlogoutSelectedBorder`   — selected/hovered button border (accent)
- `wlogoutIconColor`        — glyph color (idle)
- `wlogoutIconSelected`     — glyph color (selected/hovered)
- `wlogoutLabelColor`       — text label color

Button visuals: rounded `Rectangle` (radius ~12), fixed size (~110×110), spacing
~20 between buttons. Selected/hovered state swaps fill + border + glyph color to
the accent values above. Glyph uses the Nerd Font already available in the bar;
labels use a normal readable font (not the Minecraft pixel font), per the
"clean modern Wlogout" style choice.

## Wiring

1. **`shell.qml`** — add `import "power" as Power` and call
   `Power.Controller.init();` in `Component.onCompleted` alongside the launcher.
2. **Hyprland** — in `configs/.config/hypr/modules/keybinds.lua`, replace the
   commented line 49 with:
   ```lua
   hl.bind(v.mainMod .. " + X", hl.dsp.exec_cmd("qs ipc call power toggle"))
   ```
   (`toggle` matches the IPC handler; the launcher uses `open`, but `toggle`
   lets `mod + X` also dismiss the menu.)

## Data flow

```
mod + X  →  qs ipc call power toggle  →  Controller.isOpen flips
         →  LazyLoader instantiates Overlay  →  user selects action
         →  Quickshell.execDetached(command)  →  controller.isOpen = false
```

## Out of scope (YAGNI)

- No confirmation dialogs before actions.
- No countdown timers or auto-action.
- No per-monitor duplication logic beyond default PanelWindow behavior.
- No animations beyond simple hover state changes (optional fade can be added later).
- No configurable button set — the five actions are fixed in `Overlay.qml`.

## Testing / verification

Manual, since this is a QML shell component:

1. `qmllint` the two new files (and `Theme.qml`) for syntax/type errors.
2. Reload: restart Quickshell (`pkill qs; qs &`) and `hyprctl reload`.
3. Press `mod + X` → menu appears dimmed and focused.
4. Verify arrow navigation, Enter, number keys, mnemonics, Esc, click-outside.
5. Verify **Lock** (safe to test) locks the session. Other actions confirmed by
   command correctness (destructive — test last / with care).
