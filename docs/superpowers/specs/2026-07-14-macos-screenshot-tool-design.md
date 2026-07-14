# macOS-Style Screenshot Tool — Design

Date: 2026-07-14
Status: Approved

## Purpose

Replace the current `Screenshot.sh` (grim/slurp script bound to `SUPER+SHIFT+S/O/W`)
with a screenshot experience that mimics macOS: full-screen capture, area capture
with window hover-snap, a shutter sound, and the signature floating thumbnail
preview in the bottom-right corner that opens an annotation editor when clicked.

## Scope

In scope:
- Full-screen capture (`SUPER+SHIFT+3`) and area capture with window snap (`SUPER+SHIFT+4`).
- Floating thumbnail preview (Quickshell/QML): slides in bottom-right, ~5 s
  auto-dismiss, click opens swappy on the file.
- Shutter sound on successful capture.
- Clipboard copy of every capture (wl-copy).
- Replacing the three existing screenshot keybinds in `keybinds.lua`.

Out of scope:
- Screen recording (Cmd+Shift+5 panel).
- Removing the old `Screenshot.sh` script file (bindings stop referencing it;
  deletion can happen separately).

## Folder layout

New feature folder inside the existing Quickshell config (part of the `configs`
stow package), following the same pattern as `lock/`, `power/`, and `launcher/`:

```
configs/.config/quickshell/screenshot/
├── screenshot.sh          # entry point: screenshot.sh full | area
├── shutter.oga            # shutter sound asset (bundled copy of the
│                          # freedesktop camera-shutter sound)
├── Controller.qml         # singleton: IpcHandler + LazyLoader, init()
└── Thumbnail.qml          # bottom-right PanelWindow popup
```

`shell.qml` gains `import "screenshot" as Screenshot` and a
`Screenshot.Controller.init()` call, matching the other features.

## Behavior

### Capture flow

1. Keybind runs `~/.config/quickshell/screenshot/screenshot.sh <mode>`.
2. Geometry is resolved per mode:
   - `full` — no geometry; `grim` captures the whole output.
   - `area` — visible windows on the current workspace are read from
     `hyprctl clients -j` and piped as rectangles into `slurp`, so hovering a
     window highlights and snap-selects it, while dragging still makes a
     freehand selection. Pressing Escape in slurp cancels: the script exits
     silently (no file, no sound, no thumbnail).
3. `grim` writes to `~/Pictures/Screenshots/Screenshot YYYY-MM-DD at HH.MM.SS.png`
   (directory auto-created).
4. The image is copied to the clipboard via `wl-copy`.
5. The shutter sound plays (paplay, falling back to pw-play).
6. The script triggers the thumbnail in the running shell:
   `qs ipc call screenshot show <file>`.

### Thumbnail preview (Quickshell)

- `Controller.qml` is a singleton (same shape as `power/Controller.qml`):
  an `IpcHandler` with target `screenshot` exposing `show(path)`, and a
  `LazyLoader` that activates the `Thumbnail` window while a preview is open.
- Single instance for free: a second `show()` call replaces the current image
  and restarts the dismiss timer.
- Layer-shell window anchored bottom-right with a margin, macOS-like styling:
  rounded corners, border, drop shadow, slide-in animation from the right.
- Click → dismisses the popup and opens `swappy -f <file>` (annotate + save).
- No interaction → auto-dismisses after ~5 s (slide-out). The file is already
  saved either way, matching macOS semantics.

### Keybinds

In `configs/.config/hypr/modules/keybinds.lua`, the three existing screenshot
binds (`SUPER+SHIFT+S/O/W` → `Screenshot.sh`) are replaced with:

- `SUPER+SHIFT+3` → `~/.config/quickshell/screenshot/screenshot.sh full`
- `SUPER+SHIFT+4` → `~/.config/quickshell/screenshot/screenshot.sh area`

## Error handling

- Slurp cancelled (non-zero exit / empty selection): exit 0, no side effects.
- Screenshots directory missing: created with `mkdir -p`.
- Sound player missing or the Quickshell instance not running (`qs ipc` fails):
  capture still saves and copies; sound and thumbnail are best-effort.
- grim failure: no sound, no thumbnail, non-zero exit.

## Dependencies

All already installed: grim, slurp, wl-copy, swappy, quickshell, jq, hyprctl.
`install.sh`'s package list should include `grim slurp swappy wl-clipboard`
if any are missing from it, so fresh installs work (quickshell is already part
of the setup). No new stow package — everything lives in the existing `configs`
package.

## Testing

Manual verification on the live Hyprland session:
1. `screenshot.sh full` — file exists with macOS naming, clipboard holds image,
   sound plays, thumbnail appears and auto-dismisses.
2. `screenshot.sh area` drag — freehand region captured.
3. `screenshot.sh area` hover + click a window — window rect captured.
4. `screenshot.sh area` + Escape — no file created, silent exit.
5. Click thumbnail — swappy opens on the captured file.
6. Two captures back-to-back — second thumbnail replaces the first.
7. Keybinds `SUPER+SHIFT+3` / `SUPER+SHIFT+4` trigger the right modes after
   `hyprctl reload`.
