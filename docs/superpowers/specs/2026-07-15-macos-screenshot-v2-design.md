# macOS-Style Screenshot Tool v2 — Design

Follow-up to `2026-07-14-macos-screenshot-tool-design.md` after live user testing.
Fixes capture-quality bugs and reworks the mode split and thumbnail popup.

## Problems observed in v1 (evidence-backed)

1. **Black borders in window captures.** A window capture measured 1906x1036:
   the window box plus Hyprland's 1px border ring (sampled `rgb(3,3,3)` on all
   edges, gold-tinted corners from `general:col.active_border = aafdc253`).
   The capture box from `hyprctl clients` includes the border.
2. **Cursor baked into captures.** The slurp crosshair appears in captures even
   though grim is invoked without `-c`. Cause: NVIDIA hardware cursor is
   composited into the scanout that screencopy reads.
3. **Thumbnail-in-screenshot.** A previous capture's popup was still on screen
   and got captured into the next screenshot.
4. **Fullscreen occlusion bug.** The window-box jq filter only checks
   `mapped`/`hidden`/workspace, so windows underneath a fullscreen window still
   become slurp boxes and produce half-cut previews.
5. **Popup not draggable; MOD+drag jitters.** The popup is a layer-shell
   surface with size bindings; Hyprland MOD+drag fights them (resize
   back-and-forth while moving).
6. **Mode split wrong.** v1's `area` mode merged window-snap and freehand crop;
   the user wants them as separate modes.

## Scope

- Rework `configs/.config/quickshell/screenshot/screenshot.sh` modes and
  capture hygiene.
- Rework `Thumbnail.qml` (drag, colors) and `Controller.qml` (instant hide
  IPC, drag/hold interaction).
- Keybind changes in `configs/.config/hypr/modules/keybinds.lua`.
- New generated cursor theme asset (camera cursor) stored in the repo.

Out of scope: multi-monitor per-screen thumbnails, rounded corners on the
slurp highlight (slurp draws square-cornered rectangles only), swappy
replacement.

## Modes and keybinds

| Key | Script arg | Behavior |
|---|---|---|
| `SUPER+ALT+3` | `full` | Whole screen (all outputs), unchanged. |
| `SUPER+ALT+4` | `window` | Window picker only: visible windows become slurp boxes, hover highlights, click captures. `slurp -r` so no freehand drag is possible. |
| `SUPER+SHIFT+S` | `crop` | Pure crop: freehand rectangle drag, no window boxes. |

The v1 `area` argument is removed (not aliased). Usage line becomes
`full|window|crop`. `SUPER+SHIFT+S` does not conflict: the old v1 binds on
`SUPER+SHIFT+S/O/W` were removed in v1 Task 3.

## Capture hygiene (all modes)

Order of operations per capture:

1. `qs ipc call screenshot -- hide` (best-effort): new IPC function that hides
   the popup **instantly** — no slide-out animation — so a previous thumbnail
   can never appear in the new capture, even partially.
2. Save current `cursor:no_hardware_cursors` (via `hyprctl getoption -j`),
   set it to `1`. Restore the saved value via an EXIT `trap` so cancel and
   failure paths also restore it.
3. Mode-specific selection (slurp) if any.
4. `grim` capture.
5. Restore settings (trap), then clipboard, sound, thumbnail IPC as in v1.

### Border-free window boxes

For each window box: `x = at[0] + border_size`, `y = at[1] + border_size`,
`w = size[0] - 2*border_size`, `h = size[1] - 2*border_size`, where
`border_size` is read from `hyprctl getoption general:border_size -j` at
runtime (currently 1). Known limitation (accepted): with
`decoration:rounding = 2`, up to ~1px of corner artifact can remain in the
extreme corners.

### Fullscreen filter

When building window boxes: if any client on a monitor's active workspace has
`fullscreen != 0`, only fullscreen clients from that workspace are offered as
boxes. Windows underneath are excluded.

## Window-pick mode UX

- **slurp appearance:** dimmed background, white hover border ~2px, faint
  white fill on the hovered box. Indicative flags:
  `slurp -r -b '#00000066' -c '#FFFFFFFF' -w 2 -s '#FFFFFF22'` (exact values
  are the plan's to pin down on the live session).
- **Camera cursor:** a generated Xcursor theme, stored in the repo under the
  screenshot module (stow-managed), containing a macOS-style glyph — **dark
  camera on a white rounded square** — used for the pointer shapes slurp can
  trigger (at minimum `crosshair`, `cross`, `left_ptr`, `default`). The theme
  inherits the user's normal theme for everything else.
  During `window` mode only, the script swaps the global cursor with
  `hyprctl setcursor <camera-theme> <size>` before slurp and restores the
  previous theme/size after (trap-protected, so Escape also restores). The
  previous theme/size are read from the environment (`XCURSOR_THEME`,
  `XCURSOR_SIZE`) with sane fallbacks.
- Cursor-theme swap failing must not block the capture (best-effort, like
  sound).

## Thumbnail popup v2

- **Drag to reposition:** pressing and moving the popup beyond a small
  threshold (~6px) drags it anywhere on screen. Implementation: the popup
  keeps `right`/`bottom` anchors and adjusts its layer-surface **margins**
  during the drag — Hyprland never moves or resizes the surface, so the v1
  MOD+drag jitter cannot occur. A plain click (below the threshold) still
  opens swappy. Auto-dismiss is paused while pressed or hovered and resumes
  on release/exit. Each new capture resets the popup to bottom-right
  (margins 12/12).
- **macOS dark frame:** frame color goes from white (`#F2FFFFFF`) to macOS
  dark charcoal (`#F22A2A2A`) with a subtle light hairline
  (`border.color: #40FFFFFF`). Values may be nudged during live verification
  if the user dislikes the shade. The image keeps its rounded-corner mask.
  Shadow unchanged.
- Existing behavior kept: 5s auto-dismiss, hover-hold, click opens swappy,
  slide-in from the right, in-place image swap on successive captures.
- New `hide()` on the controller: sets `revealed = false` and `isOpen = false`
  immediately (skips the 260ms slide-out) and stops all timers. Exposed over
  IPC for the script's pre-capture call.

## Housekeeping

- Remove trailing-whitespace lint warnings in
  `configs/.config/hypr/modules/keybinds.lua` (lines 46 and 60) while editing
  the file for the new binds.

## Error handling

- Escape in slurp cancels silently (`exit 0`), no side effects left behind:
  hardware-cursor setting and cursor theme are restored by the EXIT trap.
- Capture (file + clipboard) must never depend on sound, popup, or cursor
  cosmetics — all best-effort, as in v1.
- All IPC calls use the `qs ipc call screenshot -- <fn> ...` form (`--`
  separator required on Quickshell 0.3.0).

## Testing (manual, live session)

1. `SUPER+ALT+4` on a window: capture contains no black/gold border ring
   (sample edge pixels), no cursor, no popup remnant.
2. `SUPER+ALT+4` with one window fullscreen and others beneath: only the
   fullscreen window is offered.
3. `SUPER+ALT+4`: pointer becomes the camera cursor during selection; normal
   cursor restored after capture AND after Escape. White highlight visible.
4. `SUPER+ALT+4`: dragging does nothing (window pick only, `slurp -r`).
5. `SUPER+SHIFT+S`: freehand rectangle works, no window snapping, Escape
   cancels silently.
6. `SUPER+ALT+3`: full capture, no cursor, no popup remnant.
7. Popup: plain drag repositions smoothly (no resize jitter); click opens
   swappy; hover >5s keeps it alive; new capture resets position bottom-right.
8. Popup frame is dark charcoal with light hairline.
9. `hyprctl getoption cursor:no_hardware_cursors` returns the pre-capture
   value after every mode, including a cancelled one.
10. `SUPER+SHIFT+3` still moves a window to workspace 3 (workspace binds
    untouched).
