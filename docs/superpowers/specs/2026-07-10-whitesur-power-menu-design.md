# WhiteSur Power Menu + Theme — Design

**Date:** 2026-07-10
**Branch:** `feat/quickshell-power-menu`
**Status:** Approved (design), pending implementation plan

## Goal

Two related changes to the Quickshell config:

1. **Restyle the power menu** (`power/Overlay.qml`) from the current wlogout-like row of
   5 separate cards into a unified, macOS/Big-Sur-style **frosted panel** with custom
   SVG icons and accent-blue selection.
2. **Add a new `whiteSur_dark` theme** to `Theme.qml` (a dark macOS-look palette) and make
   it the active theme.

Layout intent confirmed with user: keep the **horizontal row** of 5 actions, refined —
not a dock-pill or vertical list.

## Non-Goals

- Light WhiteSur variant (dark only for now).
- Changing power-menu behavior/keybindings/actions (Lock, Logout, Suspend, Reboot,
  Shutdown and all keyboard/mouse interaction stay exactly as they are).
- Restyling any other bar component beyond what the new theme's existing properties cover.

## Approach: Unified frosted panel (Approach A)

Chosen over "5 separate restyled cards (B)" because a single translucent container is the
defining element of the macOS look, for little extra work.

### 1. Real frosted glass via Hyprland

The translucency must be genuine compositor blur, not a flat dim. Add layer rules keyed to
the existing surface namespace `shell:power` (set in `Overlay.qml` via
`WlrLayershell.namespace`). In `configs/.config/hypr/modules/window-rules.lua`:

```lua
layerrule = blur, shell:power
layerrule = ignorealpha 0.2, shell:power
```

**Backdrop dim (darker, for focus):** per user request, the background outside the panel
should be clearly darkened so it doesn't distract. The PanelWindow dim is *darkened* from
`#35000000` to ~`#66000000` (≈40% black). Combined with the compositor blur, the
background reads as blurred *and* dimmed, pushing focus onto the frosted panel. The panel
itself stays lighter/frosted, maximizing contrast against the darkened surroundings.

### 2. The panel container

A centered rounded `Rectangle` wrapping the button `Row`:

- `radius: 22`
- fill: translucent dark, `~#CC1C1C1E` (themeable — see `wlogoutPanelBg`)
- 1px hairline border: `#26FFFFFF` (themeable — see `wlogoutPanelBorder`)
- soft drop shadow (MultiEffect shadow or a layered approach)
- internal padding around the `Row` (~24px), row `spacing` ~16px

### 3. The buttons

Rounded-square cells (icon + label), structure preserved from current delegate:

- idle: near-transparent fill (`wlogoutButtonBg`), subtle border (`wlogoutBorderColor`)
- hovered/selected: accent-blue tint fill (`wlogoutButtonBgHover`, `#330A84FF`) with
  accent border (`wlogoutSelectedBorder`, `#0A84FF`)
- selection remains the single source of highlight (hover sets `selected`, per existing
  fixed behavior) — no double-highlight regression.

### 4. Icons (user-supplied, recolored)

- Icons are **supplied and present** (Phosphor set, solid white `fill="#ffffff"`,
  `viewBox 0 0 256 256`) in `configs/.config/quickshell/power/icons/`. Actual filenames:
  `lock.svg`, `log-out.svg`, `moon.svg`, `rotate-cw.svg`, `power.svg`.
- Action → file mapping:
  Lock→`lock.svg`, Logout→`log-out.svg`, Suspend→`moon.svg`, Reboot→`rotate-cw.svg`,
  Shutdown→`power.svg`. Each action in the `actions` model gains an `icon` path (e.g.
  `"root:/power/icons/lock.svg"`) replacing the Nerd Font `glyph`.
- Rendered via `Image` (with `sourceSize` for crisp scaling) → recolored through a
  `MultiEffect` (`colorization: 1.0`, `colorizationColor:` the theme icon color).
  Source is solid white, so colorization tints the filled shape to `wlogoutIconColor`
  (idle) / `wlogoutIconSelected` (selected/hover) cleanly, preserving alpha edges.
- Label text color stays `wlogoutLabelColor`.

### 5. WhiteSur Dark theme

New `Item { id: whiteSur_dark }` in `Theme.qml` with the full property set matching the
existing theme contract. Accent = macOS dark blue `#0A84FF`.

Proposed palette:

| Property | Value | Notes |
|---|---|---|
| `barBgColor` | `#CC1C1C1E` | dark translucent menubar |
| `buttonBorderColor` | `#01000000` | near-transparent (same guard as black_flat) |
| `buttonBorderShadow` | `false` | |
| `onTop` | `true` | |
| `iconColor` | `#DDFFFFFF` | bar icons, light |
| `iconPressedColor` | `#0A84FF` | accent on press |
| `wlogoutPanelBg` (new) | `#CC1C1C1E` | frosted panel fill |
| `wlogoutPanelBorder` (new) | `#26FFFFFF` | hairline |
| `wlogoutButtonBg` | `#14FFFFFF` | idle cell |
| `wlogoutButtonBgHover` | `#330A84FF` | accent tint |
| `wlogoutBorderColor` | `#26FFFFFF` | idle cell border |
| `wlogoutSelectedBorder` | `#0A84FF` | accent |
| `wlogoutIconColor` | `#F5FFFFFF` | idle icon (via colorization) |
| `wlogoutIconSelected` | `#0A84FF` | selected icon |
| `wlogoutLabelColor` | `#CCFFFFFF` | labels |
| `barGradient` / `buttonInactive*` | transparent | flat, like black_flat |
| `buttonActiveGradient` | reuse black_flat-style | bar button press feedback |

Verify `iconColor` / `iconPressedColor` usage in `Icon.qml` before finalizing those two
values (they drive bar icons, not the power menu).

### 6. New theme properties added everywhere

`wlogoutPanelBg` and `wlogoutPanelBorder` are added to **all three** theme entries
(`windowsXP`, `black_flat`, `whiteSur_dark`) so `Theme.qml` stays the single source of
truth and no theme breaks. Values for the two existing themes: sensible translucent
defaults matching their palettes.

### 7. Activate the theme

Change `property Item get: black_flat` → `property Item get: whiteSur_dark`. Documented as
a one-line switch so the user can revert.

## Files touched

- `configs/.config/quickshell/Theme.qml` — new theme entry, 2 new props on all entries,
  flip `get`.
- `configs/.config/quickshell/power/Overlay.qml` — panel container, `Image`+`MultiEffect`
  icons, `actions` model gains `icon` paths.
- `configs/.config/quickshell/power/icons/` — SVGs already added by user (no code change,
  referenced by path).
- `configs/.config/hypr/modules/window-rules.lua` — blur layer rules.

## Verification

- `qmllint` on `Theme.qml` and `Overlay.qml` (clean).
- Restart quickshell; open menu via `mod+X`; confirm: blur visible behind panel, panel
  frosted/rounded, icons render and recolor (white idle → blue selected), keyboard nav
  (arrows/Enter/1-5/mnemonics/Esc), hover + click, backdrop-click closes.
- Confirm no double-highlight regression.
- Fallback check: if an icon file is missing, `Image` renders empty — panel still usable.

## Resolved dependency

Icons supplied and verified present (Phosphor set, white fill). No blockers remain.
