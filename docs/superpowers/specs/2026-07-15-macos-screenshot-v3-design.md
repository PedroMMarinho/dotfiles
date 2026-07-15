# macOS-Style Screenshot Tool v3 — Full-QML Freeze-First

**Date:** 2026-07-15
**Status:** Approved
**Supersedes:** `2026-07-15-macos-screenshot-v2-design.md`

## Motivation

v2 shipped with two cursor bugs and an architecture split across Bash and QML:

1. **Cursor never changes in window mode.** The camera cursor theme was applied
   via cursor-theme swapping, which silently fails on the Quickshell overlay.
2. **The pointer appears in window-mode captures.** v2 re-grabs the live screen
   after selection (select-then-capture); the `no_hardware_cursors` toggle in
   `screenshot.sh` does not keep the cursor out of the screencopy frame on this
   NVIDIA setup.
3. **Two-language orchestration.** `screenshot.sh` owns grim/magick/wl-copy and
   hands geometry to QML over a FIFO with a 100ms unmap-race timer.

v3 makes both cursor bugs structurally impossible and deletes the shell layer.

## Decisions

- **Freeze-first everywhere interactive.** Pressing the keybind captures the
  screens immediately; window-pick and crop selection happen on the frozen
  frame. The saved file is cropped from that frozen master — there is no
  second capture.
- **Separate modes stay.** Keybinds and their modes are unchanged: full,
  window-pick, crop. Same freeze-first engine underneath; no in-overlay mode
  switching.
- **Full-QML.** `screenshot.sh` is deleted. Keybinds call
  `qs ipc call screenshot -- shoot full|window|crop`. All external commands run
  via `Quickshell.Io` Process objects.
- **Everything else is unchanged:** thumbnail popup, shutter sound, save path
  (`~/Pictures/Screenshots/Screenshot YYYY-MM-DD at HH.MM.SS.png`), clipboard
  copy, keybinds.

## Architecture

Controller.qml is the single orchestrator with a state machine:

```
idle → freezing → selecting → done/cancelled → idle
```

### Components

**Controller.qml (rewritten)**
- IPC handler: `shoot(mode)`, `hide` (instant thumbnail hide), `cancel`.
- Reads `general:border_size` and `decoration:rounding` itself via a
  `hyprctl -j` Process (no longer passed as IPC args).
- Owns the capture pipeline: freeze-grab, final crop, save, `wl-copy`,
  shutter sound, thumbnail trigger, scratch cleanup.

**SelectionOverlay.qml (evolves WindowSelector.qml)**
- One overlay-layer window per monitor (`WlrLayershell.Overlay`,
  `WlrKeyboardFocus.Exclusive`).
- Sets `Qt.BlankCursor` so the compositor draws no cursor while the overlay is
  up — hardware or software, driver quirks irrelevant.
- Draws a **fake cursor**: a QML Image following the pointer. Camera glyph in
  window mode, crosshair in crop mode. No dependency on cursor themes.
- Displays its monitor's slice of the frozen master image via
  `Image.sourceClipRect`.
- Window mode: reuses v2's hit-testing, stacking-order, border-shrink and
  animated-highlight code, operating on a window-geometry snapshot taken at
  freeze time.
- Crop mode: drag rectangle with dim outside the selection and a WxH size
  readout.

**Thumbnail.qml** — unchanged.

**Assets**
- Camera glyph: reused from the `screenshot-camera` cursor theme as a plain
  image asset.
- Crosshair: drawn in QML (two hairlines).
- The `screenshot-camera` cursor *theme* is deleted from the repo — the fake
  cursor replaces it.

## Data flow

### window / crop

1. `shoot(mode)` → hide thumbnail, snapshot window geometry (window mode).
2. Overlays map **fully transparent** with `Qt.BlankCursor`.
3. ~80ms settle timer (cursor gone from the frame, thumbnail unmapped).
4. One `grim` of the whole layout → scratch master PNG (fixed path in `/tmp`).
5. Overlays turn opaque, each showing its slice of the master; selection UI
   and fake cursor appear. Screens look frozen.
6. User selects (click window / drag region) → overlays unmap immediately.
7. `magick master.png -crop WxH+X+Y +repage` → final file (crop coordinates
   are global logical == global pixels at scale 1).
8. `wl-copy < file`, shutter sound (`paplay`/`pw-play`), thumbnail `show`,
   delete scratch.

### full

Transparent overlay maps (cursor hiding only) → settle → `grim` straight to
the final file → unmap → step 8 above. No selection UI.

### cancel

Escape or right-click → unmap overlays, delete scratch, no file, no sound,
no thumbnail.

## Error handling

- `grim` or `magick` non-zero exit: tear down overlays, delete scratch,
  `console.error`; no file, no sound, no thumbnail.
- `shoot` while a session is active: cancel the in-flight session, start the
  new one.
- Scratch master uses a fixed `/tmp` path, deleted on every exit path; a crash
  leaves at most one stale file overwritten by the next run.
- No FIFO and no blocked reader exist anymore; Escape always tears down.

## Assumptions

- Monitor scale = 1: Hyprland logical coordinates equal grim pixel
  coordinates (carried over from v2; true on this setup).
- Quickshell is running (it is the session shell); there is no standalone
  fallback path.

## Testing (UAT)

- All three modes on both monitors.
- Play a video, invoke window and crop modes: frame visibly freezes; saved
  file matches the frozen frame, not the live screen.
- Camera cursor visible in window mode; crosshair in crop mode.
- Pointer appears in **zero** captures across all modes.
- Escape and right-click cancel from both interactive modes: no file, no
  sound, scratch cleaned up.
- Clipboard, shutter sound, thumbnail all still work.
- Rapid double-press of a keybind does not wedge the state machine.
- `ls /tmp` after cancelled and completed runs: no stray scratch files.

## Deletions

- `configs/.config/quickshell/screenshot/screenshot.sh`
- `screenshot-camera` cursor theme directory
- FIFO handling, `pickReplyTimer`, `no_hardware_cursors` toggling, trap/restore
  logic (all v2 mechanisms subsumed by freeze-first).
