# Collapsible System Tray — Design

**Date:** 2026-07-22
**Component:** `configs/.config/quickshell/bar/blocks/SystemTray.qml`

## Goal

Wrap the bar's system tray icons in a toggle. An arrow sits to the **right** of
the tray icons; clicking it collapses or expands the icons with a smooth
animation. The arrow points **right (▶) when collapsed** and **left (◀) when
expanded**.

## Decisions

- **Animation:** slide + clip. The tray area's width animates between full and 0,
  with icons clipped so they retract toward the arrow.
- **Default state:** collapsed on startup.
- **Arrow transition:** swap glyph — two chevron glyphs (▶ / ◀) that cross-fade.

## Structure

`SystemTray.qml` becomes a `RowLayout` (the root block) with two children laid
left → right:

```
[  clip container (existing tray icons)  ][ arrow toggle ]
        width animates 0 ⇄ full              always the anchor
```

### 1. Clip container

- An `Item { clip: true }` that holds the **existing** `Repeater` / icon
  `RowLayout` unchanged (delegate logic, `hiddenIds` filter, tooltip, menu,
  scroll — all verbatim).
- The inner icon row is anchored to the container's **right** edge
  (`anchors.right: parent.right`, vertically centered) so that as the container
  width shrinks, icons retract toward the arrow rather than away from it.
- Width driven by state:
  - `Layout.preferredWidth: root.expanded ? iconRow.implicitWidth : 0`
  - `Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }`
- Starts at `0` (collapsed) with **no** startup animation — the `Behavior` only
  fires on change, and the initial binding evaluates to `0` directly.
- Fills the bar height.

### 2. Arrow toggle

- Reuses `BarBlock` for free hover-highlight, click handling, and consistent
  sizing.
- Content: two overlapping chevron `Text` glyphs that cross-fade:
  - `▶` (points right): `opacity: root.expanded ? 0 : 1` — shown when collapsed
  - `◀` (points left): `opacity: root.expanded ? 1 : 0` — shown when expanded
  - each with `Behavior on opacity { NumberAnimation { duration: 200 } }`
  - white; rendered with a non-emoji font so they draw as crisp triangles
    (force text presentation, e.g. `▶︎`).
- `onClicked: root.expanded = !root.expanded`

### State

- Single source of truth on the root: `property bool expanded: false`. Drives
  both the clip width and the glyph opacities.

## Empty-tray behavior

When there are zero tray items (`repeater.count === 0`), the entire block —
arrow included — is hidden, so there is never a dead toggle for an empty tray.
It reappears the moment an item registers.

## Scope

- **Touched:** `bar/blocks/SystemTray.qml` (rewritten as a wrapper).
- **Untouched:** `bar/Bar.qml` (still drops in `Blocks.SystemTray {}`), the icon
  delegate behavior, and the `hiddenIds` filter.

## Verification

- `qs-check.sh` must exit 0 (QML loads cleanly).
- Visual: bar starts with only the ▶ arrow; clicking expands icons leftward-out
  of the arrow with a smooth width slide and the glyph cross-fades to ◀;
  clicking again collapses. Block disappears when the tray is empty.
