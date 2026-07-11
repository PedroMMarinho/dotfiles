# macOS Lock Screen (Quickshell) — Design

**Date:** 2026-07-11
**Status:** Approved, ready for implementation planning

## Summary

A macOS-style (Sequoia/Sonoma) lock screen for the Hyprland + Quickshell
desktop, triggered by `MOD + L`. Built natively in Quickshell using the secure
`WlSessionLock` (ext-session-lock) protocol with real PAM password
authentication. Visually and architecturally consistent with the existing
`whiteSur_dark` theme and `power/` menu module.

## Goals

- `MOD + L` locks the session with a macOS-looking screen.
- Real authentication (PAM) — not a fake fullscreen overlay.
- Secure: if the QML client crashes, the compositor keeps the session locked.
- Multi-monitor aware.
- Visually cohesive with the existing macOS WhiteSur theme.

## Non-Goals (YAGNI)

- No power/restart/sleep buttons on the lock screen (macOS has none by default).
- No fingerprint / "Touch ID" (no reader on this desktop).
- No changes to `hypridle.conf` / suspend behavior in this iteration. Only
  `MOD + L` triggers the new lock. (Auto-lock on idle/suspend is currently
  broken because `hyprlock` is not installed, but wiring that up is deferred to
  a later iteration by explicit user choice.)

## Architecture

Mirrors the existing `power/` module pattern. Quickshell auto-registers
`pragma Singleton` QML files by directory, so no `qmldir` is needed (same as
`power/`).

New folder: `configs/.config/quickshell/lock/`

- **`Controller.qml`** (`pragma Singleton`) — the state machine and IPC entry
  point. Contains:
  - An `IpcHandler` with `target: "lock"` exposing a `lock()` function (and
    optionally `unlock()` for debugging).
  - A `WlSessionLock` (from `Quickshell.Wayland`). Setting its `locked`
    property to `true` instructs the **compositor** to lock the session and
    display the lock surface on every screen. Because the lock is enforced by
    the compositor, a crash of the QML client leaves the session locked on a
    blank surface rather than unlocked — this is the security guarantee of the
    ext-session-lock protocol.
  - A `PamContext` (from `Quickshell.Services.Pam`) for password verification.
  - Shared authentication state: the typed password buffer, a "checking" flag,
    and a "failed" pulse — all held here so every per-monitor surface shares one
    source of truth.

- **`Surface.qml`** — a `WlSessionLockSurface` component providing the macOS UI.
  Quickshell instantiates one per connected monitor automatically. Each surface
  renders the same UI and binds to the shared Controller state, so typing on any
  monitor updates the single shared password buffer.

- **`avatars/avatar.png`** — user avatar image. Provided by the user later; the
  directory is created now with the path referenced. The UI falls back to a
  generic macOS-style user glyph when the file is absent so nothing breaks
  before the image is added.

## Data Flow

```
MOD + L
  → keybind runs: qs ipc call lock lock
  → Controller IpcHandler.lock() sets WlSessionLock.locked = true
  → compositor locks the session and shows Surface.qml on every screen

user types password + presses Enter
  → Controller starts PamContext with the buffered password
  → on success: Controller sets WlSessionLock.locked = false → session unlocks
  → on failure: pill shakes + red tint, password buffer cleared, stays locked
```

## Visual Design (standard macOS Sequoia)

- **Background:** blurred wallpaper. Source path is configurable, defaulting to
  the path hyprlock already references
  (`$HOME/.config/hypr/wallpaper_effects/current_wallpaper`). Rendered via
  `Image` + `MultiEffect` blur plus a subtle dark scrim for legibility. If the
  file is missing (it currently is), fall back to a solid dark theme color from
  `Theme.qml`.
- **Clock:** large centered time (`HH:mm`) with weekday + date below, positioned
  in the upper third. Updated via `SystemClock`. Uses the theme font (Adwaita
  Sans for the time, matching hyprlock's style).
- **Avatar:** circular image masked to a circle, from `lock/avatars/avatar.png`.
  Falls back to a generic macOS user glyph if the file does not exist.
- **Name:** the user's full name / username, centered below the avatar.
- **Password pill:** a rounded capsule `TextField` with `echoMode: Password`
  (dot bullets), placeholder text "Enter Password", and a small `›` submit
  affordance on the right edge. On a failed attempt it plays a horizontal shake
  animation, tints red briefly, and clears.
- **Colors / theme:** pulled from the existing `Theme.qml` `whiteSur_dark`
  palette so the lock screen matches the power menu and bar.

## Integration Points

- **`configs/.config/hypr/modules/keybinds.lua`** (line ~48): replace the
  commented-out `LockScreen.sh` binding with:
  `hl.bind(v.mainMod .. " + L", hl.dsp.exec_cmd("qs ipc call lock lock"))`
- **`configs/.config/quickshell/shell.qml`**: add `import "lock" as Lock` and
  call `Lock.Controller.init();` inside `Component.onCompleted` alongside the
  existing `Launcher.Controller.init()` / `Power.Controller.init()`.

## Error Handling & Safety

- **Compositor-enforced lock:** a QML crash leaves the session locked (blank
  surface), never unlocked.
- **PAM failures:** show a failed-attempt indication (shake + red), clear the
  buffer, remain locked. Do not leak whether the username or password was wrong.
- **Multi-monitor:** one `WlSessionLockSurface` per screen; shared Controller
  state; a single PAM check runs per submit regardless of which monitor typed.
- **Missing assets:** absent wallpaper → solid theme color; absent avatar →
  generic glyph. Neither blocks unlocking.
- **Lockout risk during development:** keep a TTY escape hatch ready
  (`Ctrl+Alt+F2`, log in, `loginctl unlock-session`) while testing. `qmllint`
  every file before Quickshell loads it.

## Testing / Verification

Session locks cannot be meaningfully unit-tested; verification is manual with a
safety escape hatch:

1. `qmllint` passes on `Controller.qml` and `Surface.qml`.
2. `qs ipc call lock lock` locks the session; UI renders on all monitors.
3. Clock and date display and update; wallpaper (or fallback) renders.
4. Wrong password → shake + clear, session stays locked.
5. Correct password → clean unlock, desktop restored.
6. No bypass: `Esc`, killing focus, and switching workspaces do not unlock.
7. `MOD + L` keybind triggers the same flow after the Hyprland config reload.

## Files

| Action | Path |
|---|---|
| New | `configs/.config/quickshell/lock/Controller.qml` |
| New | `configs/.config/quickshell/lock/Surface.qml` |
| New | `configs/.config/quickshell/lock/avatars/` (avatar.png provided later) |
| Modify | `configs/.config/quickshell/shell.qml` |
| Modify | `configs/.config/hypr/modules/keybinds.lua` |
