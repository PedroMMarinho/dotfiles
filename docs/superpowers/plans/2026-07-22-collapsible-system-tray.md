# Collapsible System Tray Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wrap the bar's system tray icons in an arrow toggle that collapses/expands them with a smooth width-slide animation and a cross-fading arrow glyph.

**Architecture:** `SystemTray.qml` becomes a root `RowLayout` holding (1) a `clip:true` container whose width animates `0 ⇄ full` with the existing icon `Repeater` anchored to its right edge, and (2) a `BarBlock` arrow toggle with two overlapping chevron `Text` glyphs that cross-fade. A single `expanded` bool drives both.

**Tech Stack:** Quickshell (QML), Qt Quick, `qmllint` for parse checks, a live hot-reloading `qs` instance for visual verification.

## Global Constraints

- Only one file changes: `configs/.config/quickshell/bar/blocks/SystemTray.qml`. Do **not** touch `bar/Bar.qml`.
- Preserve the existing icon delegate behavior verbatim: left-click `activate()`, middle-click `secondaryActivate()`, right-click menu, wheel `scroll()`, tooltip, and the `hiddenIds` filter (`["nm-applet", "blueman", "Fcitx"]`).
- Default state on startup: **collapsed** (`expanded: false`), with **no** startup animation.
- Arrow points **▶ right when collapsed**, **◀ left when expanded**.
- Animation durations: width slide `200ms` `Easing.OutCubic`; glyph opacity `200ms` (default easing).

**TDD note:** This is a visual QML bar widget with no unit-test harness in this repo. The "test" cycle here is a static `qmllint` parse check plus visual verification against the live hot-reloading `qs` instance. That substitution is intentional; do not scaffold a test framework.

---

### Task 1: Rewrite SystemTray.qml as a collapsible wrapper

**Files:**
- Modify (full rewrite): `configs/.config/quickshell/bar/blocks/SystemTray.qml`

**Interfaces:**
- Consumes: `BarBlock` (from `bar/BarBlock.qml` — `content: Item`, `onClicked: function(){}`), `Tooltip` (from `bar/Tooltip.qml`), both resolved via `import "root:/bar"`. `SystemTray.items.values` from `Quickshell.Services.SystemTray`.
- Produces: a self-contained `Blocks.SystemTray {}` widget; no new public interface for other files.

- [ ] **Step 1: Capture the current baseline visually**

The `qs` instance hot-reloads, so confirm the tray currently renders before changing it. Run:

```bash
grim -o "$(hyprctl monitors -j | jq -r '.[0].name')" /tmp/tray-before.png && echo saved
```

Expected: `saved`. (Optional sanity check — the bar's tray icons are visible in the image.)

- [ ] **Step 2: Rewrite the file with the wrapper**

Replace the **entire** contents of `configs/.config/quickshell/bar/blocks/SystemTray.qml` with:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/bar"

RowLayout {
  id: root
  spacing: 2

  // Single source of truth: drives both the clip width and the arrow glyphs.
  property bool expanded: false

  // Hide the whole block (arrow included) when there are no tray items, so we
  // never present a dead toggle for an empty tray.
  visible: trayRepeater.count > 0

  // Clip container — width animates 0 <-> full. The icon row inside is anchored
  // to the RIGHT edge so icons retract toward the arrow as it collapses.
  Item {
    id: trayClip
    clip: true
    Layout.fillHeight: true
    Layout.preferredWidth: root.expanded ? iconRow.implicitWidth : 0

    Behavior on Layout.preferredWidth {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    RowLayout {
      id: iconRow
      spacing: 5
      height: parent.height
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter

      Repeater {
        id: trayRepeater
        model: ScriptModel {
          // Note: don't filter on item.id == "chrome_status_icon_1" here — every
          // Electron app (Discord, WhatsApp, ...) reports that same generic id.
          // To hide a specific app, filter on item.tooltipTitle instead.
          //
          // nm-applet and blueman are the exception: both report unique, stable ids
          // (verified over DBus), so filtering them by id is safe. They are hidden
          // rather than killed — blueman-applet still supplies the BlueZ pairing
          // agent that renders passkey prompts, which Quickshell's Bluetooth API
          // does not provide.
          readonly property var hiddenIds: ["nm-applet", "blueman", "Fcitx"]
          values: [...SystemTray.items.values]
            .filter(i => hiddenIds.indexOf(i.id) === -1)
        }

        MouseArea {
          id: delegate
          required property SystemTrayItem modelData
          property alias item: delegate.modelData

          Layout.fillHeight: true
          implicitWidth: icon.implicitWidth + 5

          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          hoverEnabled: true

          onClicked: event => {
            if (event.button == Qt.LeftButton) {
              item.activate();
            } else if (event.button == Qt.MiddleButton) {
              item.secondaryActivate();
            } else if (event.button == Qt.RightButton) {
              menuAnchor.open();
            }
          }

          onWheel: event => {
            event.accepted = true;
            const points = event.angleDelta.y / 120
            item.scroll(points, false);
          }

          IconImage {
            id: icon
            anchors.centerIn: parent
            source: item.icon
            implicitSize: 16
          }

          QsMenuAnchor {
            id: menuAnchor
            menu: item.menu

            anchor.window: delegate.QsWindow.window
            anchor.adjustment: PopupAdjustment.Flip

            anchor.onAnchoring: {
              const window = delegate.QsWindow.window;
              const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, delegate.height);

              menuAnchor.anchor.rect = widgetRect;
            }
          }

          Tooltip {
            relativeItem: delegate.containsMouse ? delegate : null

            Label {
              text: delegate.item.tooltipTitle || delegate.item.id
            }
          }
        }
      }
    }
  }

  // Arrow toggle — reuses BarBlock for hover highlight + click + sizing.
  BarBlock {
    id: arrowBlock
    onClicked: function() { root.expanded = !root.expanded; }

    content: Item {
      implicitWidth: 14
      implicitHeight: 14

      // Two overlapping glyphs cross-fade. ︎ forces text presentation so
      // the triangles render as crisp glyphs instead of color emoji.
      Text {
        anchors.centerIn: parent
        text: "▶︎"   // ▶ collapsed (points right)
        color: "white"
        font.family: "JetBrainsMono"
        font.pointSize: 10
        opacity: root.expanded ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }
      Text {
        anchors.centerIn: parent
        text: "◀︎"   // ◀ expanded (points left)
        color: "white"
        font.family: "JetBrainsMono"
        font.pointSize: 10
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }
    }
  }
}
```

- [ ] **Step 3: Static parse check with qmllint**

Run:

```bash
cd /home/marinho/dotfiles/configs/.config/quickshell && qmllint bar/blocks/SystemTray.qml
```

Expected: exit code 0. Warnings about unresolved Quickshell modules/types (`Quickshell.Services.SystemTray`, `IconImage`, `SystemTrayItem`, etc.) are **pre-existing and acceptable** — qmllint cannot resolve Quickshell's C++-registered types. What must NOT appear: `Syntax error`, `Unexpected token`, unbalanced-brace, or "expected token" messages. If any of those appear, the rewrite has a typo — fix it before continuing.

- [ ] **Step 4: Verify the live reload has no load errors**

The running `qs` instance reloads on save. Confirm it is still alive and did not fault on the new file:

```bash
pgrep -a qs
```

Expected: the `qs` process is listed (same or restarted pid). If it is gone, the QML failed to load — re-run it in the foreground to read the error:

```bash
cd /home/marinho/dotfiles/configs/.config/quickshell && timeout 3 qs 2>&1 | grep -iE "error|warning: .*SystemTray|cannot" | head
```

Fix any reported error in `SystemTray.qml` and repeat from Step 3.

- [ ] **Step 5: Visual check — collapsed default**

Capture the bar and confirm the tray is collapsed to just the ▶ arrow (icons hidden), assuming at least one tray item exists:

```bash
grim -o "$(hyprctl monitors -j | jq -r '.[0].name')" /tmp/tray-collapsed.png && echo saved
```

Expected: `saved`. In the image, where the tray icons used to be there is now a single right-pointing arrow (▶) and no visible tray icons. (If the tray is empty, the whole block is correctly absent — start an app with a tray icon to verify, or accept the empty-tray-hidden behavior.)

- [ ] **Step 6: Manual interaction check — expand/collapse**

Click the ▶ arrow in the bar. Observe:
- The tray icons slide out to the left of the arrow with a smooth ~200ms width animation (they emerge tucked from the arrow, not popping in).
- The glyph cross-fades from ▶ to ◀.

Click ◀ again. Observe the icons slide back in (retracting toward the arrow) and the glyph cross-fades back to ▶.

Optionally capture the expanded state:

```bash
grim -o "$(hyprctl monitors -j | jq -r '.[0].name')" /tmp/tray-expanded.png && echo saved
```

Expected: icons visible to the left of a left-pointing arrow (◀). If icons slide the *wrong* direction (retract away from the arrow / clip on the right), the `anchors.right` on `iconRow` is missing or wrong — fix and repeat from Step 3.

- [ ] **Step 7: Commit**

```bash
cd /home/marinho/dotfiles && git add configs/.config/quickshell/bar/blocks/SystemTray.qml && git commit -m "Add collapsible toggle to system tray

Wrap the tray icons in a clip container whose width animates 0<->full,
with an arrow BarBlock toggle whose glyph cross-fades between ▶ (collapsed)
and ◀ (expanded). Starts collapsed; hides entirely when the tray is empty.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

Expected: commit succeeds.

---

## Self-Review

**Spec coverage:**
- Arrow to the right of icons → `BarBlock` is the last child of the root `RowLayout`. ✓
- Click to open/close → `arrowBlock.onClicked` toggles `expanded`. ✓
- ▶ when closed, ◀ when open → the two `Text` glyphs bound to `expanded`. ✓
- Smooth animation showing icons → `Behavior on Layout.preferredWidth` (200ms OutCubic) on `trayClip`. ✓
- Smooth arrow change → `Behavior on opacity` cross-fade on both glyphs. ✓
- Slide + clip toward the arrow → `clip:true` container + `iconRow` anchored right. ✓
- Start collapsed, no startup animation → `expanded: false`, Behavior fires only on change. ✓
- Empty-tray hide → `visible: trayRepeater.count > 0`. ✓
- Untouched delegate behavior + `hiddenIds` → copied verbatim into `iconRow`. ✓

**Placeholder scan:** No TBD/TODO; full file content provided; all commands concrete. ✓

**Type/name consistency:** `root.expanded`, `trayClip`, `iconRow`, `trayRepeater`, `arrowBlock` referenced consistently across the file. `BarBlock` `content`/`onClicked` interface matches `bar/BarBlock.qml`. ✓
