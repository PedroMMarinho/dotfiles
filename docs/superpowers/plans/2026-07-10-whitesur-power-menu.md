# WhiteSur Power Menu + Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Quickshell power menu into a macOS/Big-Sur-style frosted panel (custom SVG icons, accent-blue selection, real compositor blur, darkened backdrop for focus) and add a new active `whiteSur_dark` theme.

**Architecture:** Three independent changes. (1) `Theme.qml` gains a `whiteSur_dark` palette entry plus two new panel properties on every theme, and becomes the active theme. (2) Hyprland gets a Lua `layer_rule` that blurs the power-menu layer surface. (3) `power/Overlay.qml` wraps its button row in a single frosted `Rectangle`, swaps Nerd-Font glyphs for recolored `Image` SVGs (`MultiEffect` colorization), and darkens the backdrop.

**Tech Stack:** Quickshell (Qt6 QML), `QtQuick.Effects` (`MultiEffect`), Hyprland Lua config (`hl.layer_rule`), Phosphor SVG icons.

## Global Constraints

- Do NOT change power-menu behavior: actions (Lock, Logout, Suspend, Reboot, Shutdown), commands, and all keyboard/mouse interaction (arrows/Enter/1-5/mnemonics l/e/s/r/p, Esc, hover-selects, tap-activates, backdrop-click-closes) stay identical.
- Selection is the single highlight source: hover sets `root.selected`; never add a second hover-based highlight (avoids the previously-fixed double-highlight bug).
- `Theme.qml` is the single source of truth — every color the power menu uses comes from a `Theme.get.*` property, and every property exists on ALL theme entries so no theme breaks.
- Icons are already present at `configs/.config/quickshell/power/icons/`: `lock.svg`, `log-out.svg`, `moon.svg`, `rotate-cw.svg`, `power.svg` (Phosphor, solid white fill).
- No automated test harness exists for this Quickshell config. Per-task verification = `qmllint` (best-effort) + hot-reload runtime observation. Quickshell (`qs`, currently running) hot-reloads on file save; if it doesn't pick up a change, restart with `qs kill` then `qs &`. Open the menu with `qs ipc call power toggle`.
- Accent color for `whiteSur_dark` is macOS dark blue `#0A84FF`.

---

## Task 1: WhiteSur Dark theme + panel properties

**Files:**
- Modify: `configs/.config/quickshell/Theme.qml`

**Interfaces:**
- Produces: two new string properties on every theme entry — `wlogoutPanelBg`, `wlogoutPanelBorder` — plus a new theme `Item { id: whiteSur_dark }` exposing the full existing theme contract. `Theme.get` resolves to `whiteSur_dark`. Task 3 consumes `Theme.get.wlogoutPanelBg`, `Theme.get.wlogoutPanelBorder`, and the existing `wlogout*` colors.

- [ ] **Step 1: Add the two new panel properties to the `windowsXP` theme**

In `configs/.config/quickshell/Theme.qml`, inside `Item { id: windowsXP ... }`, directly after the `// Wlogout power menu` block (after the `wlogoutLabelColor` line), add:

```qml
    // Frosted panel (power menu container)
    property string wlogoutPanelBg: "#CC12244F"
    property string wlogoutPanelBorder: "#55FFFFFF"
```

- [ ] **Step 2: Add the two new panel properties to the `black_flat` theme**

Inside `Item { id: black_flat ... }`, directly after its `wlogoutLabelColor` line, add:

```qml
    // Frosted panel (power menu container)
    property string wlogoutPanelBg: "#CC1A1A1A"
    property string wlogoutPanelBorder: "#33FFFFFF"
```

- [ ] **Step 3: Add the `whiteSur_dark` theme entry**

Immediately after the closing `}` of the `black_flat` `Item` (before the final `}` that closes the `Singleton`), add a new theme item. It reuses `black_flat`'s flat/transparent gradients and active-button gradient:

```qml
  Item {
    id: whiteSur_dark

    property string barBgColor: "#CC1C1C1E"
    property string buttonBorderColor: "#01000000" // near-transparent (same guard as black_flat)
    property bool buttonBorderShadow: false
    property bool onTop: true
    property string iconColor: "#DDFFFFFF"
    property string iconPressedColor: "#0A84FF"
    // Wlogout power menu
    property string wlogoutButtonBg: "#14FFFFFF"
    property string wlogoutButtonBgHover: "#330A84FF"
    property string wlogoutBorderColor: "#26FFFFFF"
    property string wlogoutSelectedBorder: "#0A84FF"
    property string wlogoutIconColor: "#F5FFFFFF"
    property string wlogoutIconSelected: "#0A84FF"
    property string wlogoutLabelColor: "#CCFFFFFF"
    // Frosted panel (power menu container)
    property string wlogoutPanelBg: "#CC1C1C1E"
    property string wlogoutPanelBorder: "#26FFFFFF"
    property Gradient barGradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
    }
    property Gradient buttonInactiveGradientV: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
    }
    property Gradient buttonInactiveGradientH: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
    }
    property Gradient buttonActiveGradient: Gradient {
      GradientStop { position: 0.92; color: "#FF000000" }
      GradientStop { position: 0.93; color: "#FFFFFFFF" }
      GradientStop { position: 1.0; color: "#FFFFFFFF" }
    }
  }
```

- [ ] **Step 4: Make `whiteSur_dark` the active theme**

Change the `get` line near the top of the `Singleton`:

```qml
  property Item get: whiteSur_dark
```

(Was `black_flat`. This single line switches themes; revert to `black_flat` anytime.)

- [ ] **Step 5: Lint the file**

Run: `qmllint configs/.config/quickshell/Theme.qml`
Expected: no output / exit 0. If it reports Quickshell-import warnings (e.g. cannot resolve `Quickshell`), those are import-path noise, not errors in this change — the authoritative check is Step 6.

- [ ] **Step 6: Verify at runtime**

Run: `qs kill 2>/dev/null; (qs >/tmp/qs.log 2>&1 &) ; sleep 2; grep -i "error\|warning" /tmp/qs.log || echo "clean load"`
Expected: `clean load` (or no QML errors mentioning `Theme.qml`). The bar should now render with the dark WhiteSur `barBgColor`. If errors mention a missing property, a `wlogout*`/`wlogoutPanel*` property was omitted from one theme — add it.

- [ ] **Step 7: Commit**

```bash
git add configs/.config/quickshell/Theme.qml
git commit -m "feat(quickshell): add whiteSur_dark theme and frosted panel colors"
```

---

## Task 2: Hyprland blur for the power-menu layer

**Files:**
- Modify: `configs/.config/hypr/modules/window-rules.lua`

**Interfaces:**
- Consumes: the layer namespace `shell:power`, set in `power/Overlay.qml` via `WlrLayershell.namespace: "shell:power"`.
- Produces: a compositor blur applied behind the power-menu surface. No QML dependency.

- [ ] **Step 1: Add the layer rule**

Append to the end of `configs/.config/hypr/modules/window-rules.lua`:

```lua
-- Blur the Quickshell power-menu layer so the frosted panel reads as real glass.
hl.layer_rule({
    name         = "power-menu-blur",
    match        = { namespace = "^shell:power$" },
    blur         = true,
    ignore_alpha = 0.2,
})
```

(`ignore_alpha = 0.2` blurs only regions with alpha above 0.2 — the darkened backdrop (alpha ~0.4) and the panel both qualify, so the whole surface is blurred beneath its dim.)

- [ ] **Step 2: Reload Hyprland config**

Run: `hyprctl reload`
Expected: `ok`.

- [ ] **Step 3: Verify the rule is live**

Open the menu, then inspect layers:
Run: `qs ipc call power toggle; sleep 1; hyprctl layers | grep -i "shell:power" ; qs ipc call power toggle`
Expected: a line showing the `shell:power` namespace layer is present (confirming the namespace matches the rule). Visually, when the menu is open the wallpaper/windows behind it should appear blurred. If not blurred, run `hyprctl layers` while the menu is open and confirm the exact namespace string, then adjust the `match.namespace` regex to match it.

- [ ] **Step 4: Commit**

```bash
git add configs/.config/hypr/modules/window-rules.lua
git commit -m "feat(hypr): blur the quickshell power-menu layer surface"
```

---

## Task 3: Frosted panel + SVG icons in the power menu

**Files:**
- Modify: `configs/.config/quickshell/power/Overlay.qml` (full render section rewrite)

**Interfaces:**
- Consumes: `Theme.get.wlogoutPanelBg`, `Theme.get.wlogoutPanelBorder`, `Theme.get.wlogoutButtonBg`, `Theme.get.wlogoutButtonBgHover`, `Theme.get.wlogoutBorderColor`, `Theme.get.wlogoutSelectedBorder`, `Theme.get.wlogoutIconColor`, `Theme.get.wlogoutIconSelected`, `Theme.get.wlogoutLabelColor` (all from Task 1); icon SVGs at `root:/power/icons/`.
- Produces: final power-menu UI. No downstream consumers.

- [ ] **Step 1: Replace the file with the redesigned overlay**

Overwrite `configs/.config/quickshell/power/Overlay.qml` with exactly this. Changes vs. current: added `import QtQuick.Effects`; `actions` now carry `icon` paths instead of `glyph`; backdrop `color` darkened to `#66000000`; the `Row` is wrapped in a frosted `Rectangle` (`panel`) with a `MultiEffect` drop shadow; each icon is a recolored `Image` via `layer.effect: MultiEffect`. Keyboard/mouse logic is byte-for-byte the same as before.

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/" // for Theme singleton

PanelWindow {
    id: root

    required property var controller

    // Five actions, left -> right. mnemonic = direct-activate key.
    readonly property var actions: [
        { label: "Lock",     icon: "root:/power/icons/lock.svg",      mnemonic: "l", command: ["loginctl", "lock-session"] },
        { label: "Logout",   icon: "root:/power/icons/log-out.svg",   mnemonic: "e", command: ["hyprctl", "dispatch", "exit"] },
        { label: "Suspend",  icon: "root:/power/icons/moon.svg",      mnemonic: "s", command: ["systemctl", "suspend"] },
        { label: "Reboot",   icon: "root:/power/icons/rotate-cw.svg", mnemonic: "r", command: ["systemctl", "reboot"] },
        { label: "Shutdown", icon: "root:/power/icons/power.svg",     mnemonic: "p", command: ["systemctl", "poweroff"] }
    ]

    property int selected: 0

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "#66000000" // darkened backdrop so focus stays on the panel
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "shell:power"

    function activate(index) {
        const action = root.actions[index];
        Quickshell.execDetached({ command: action.command });
        root.controller.isOpen = false;
    }

    // Click on the dim backdrop (outside the panel) closes the menu.
    MouseArea {
        anchors.fill: parent
        onClicked: root.controller.isOpen = false
    }

    // Keyboard handling lives on a focused item covering the window.
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.controller.isOpen = false

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left) {
                root.selected = (root.selected - 1 + root.actions.length) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.selected = (root.selected + 1) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate(root.selected);
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                root.activate(event.key - Qt.Key_1);
                event.accepted = true;
            } else if (event.text.length === 1) {
                for (let i = 0; i < root.actions.length; i++) {
                    if (root.actions[i].mnemonic === event.text.toLowerCase()) {
                        root.activate(i);
                        event.accepted = true;
                        break;
                    }
                }
            }
        }

        // Frosted macOS-style container holding the action row.
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: buttonRow.width + 48
            height: buttonRow.height + 48
            radius: 22
            color: Theme.get.wlogoutPanelBg
            border.width: 1
            border.color: Theme.get.wlogoutPanelBorder

            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "#88000000"
                shadowBlur: 1.0
                shadowVerticalOffset: 8
            }

            Row {
                id: buttonRow
                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        id: button
                        required property int index
                        required property var modelData

                        readonly property bool active: root.selected === index

                        width: 104
                        height: 104
                        radius: 16
                        color: active ? Theme.get.wlogoutButtonBgHover : Theme.get.wlogoutButtonBg
                        border.width: active ? 2 : 1
                        border.color: active ? Theme.get.wlogoutSelectedBorder : Theme.get.wlogoutBorderColor

                        HoverHandler {
                            onHoveredChanged: if (hovered) root.selected = button.index
                        }

                        TapHandler {
                            onTapped: root.activate(button.index)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Image {
                                id: iconImg
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: button.modelData.icon
                                sourceSize.width: 40
                                sourceSize.height: 40
                                width: 40
                                height: 40
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    colorizationColor: button.active ? Theme.get.wlogoutIconSelected : Theme.get.wlogoutIconColor
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: button.modelData.label
                                font.pixelSize: 14
                                color: Theme.get.wlogoutLabelColor
                            }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Lint the file**

Run: `qmllint configs/.config/quickshell/power/Overlay.qml`
Expected: no output / exit 0, or only Quickshell/`root:` import-resolution warnings (import-path noise). Any error naming `MultiEffect`, `Image`, or a syntax problem is real — fix it. Authoritative check is Step 3.

- [ ] **Step 3: Verify at runtime**

Run: `qs kill 2>/dev/null; (qs >/tmp/qs.log 2>&1 &); sleep 2; qs ipc call power toggle`
Then look at the screen and confirm ALL of:
- A single rounded frosted panel is centered, containing all 5 buttons in one row.
- Background outside the panel is clearly darkened AND blurred (blur from Task 2).
- Each button shows its Phosphor icon (lock / logout / moon / rotate / power) above its label.
- Icons are white when idle; the selected button's icon and border turn accent-blue `#0A84FF`.
- Arrow keys move selection (wrapping); hovering a button selects it (only ONE button highlighted at a time — no double highlight); clicking a button or pressing its number/mnemonic activates it; Esc and clicking the dark backdrop both close the menu.

Then close it: `qs ipc call power toggle` (if still open).
Also check logs: `grep -i "error\|warning" /tmp/qs.log || echo "clean load"` → expect `clean load`.

If icons render as solid blocks (not tinted), confirm `colorization`/`colorizationColor` spelling. If icons are invisible, confirm the `source` paths resolve (`root:/power/icons/...`) and the files exist.

- [ ] **Step 4: Commit**

```bash
git add configs/.config/quickshell/power/Overlay.qml
git commit -m "feat(quickshell): frosted macOS-style power menu with SVG icons"
```

---

## Self-Review

**Spec coverage:**
- Frosted panel container → Task 3 (`panel` Rectangle, radius 22, themed bg/border, MultiEffect shadow). ✓
- Real frosted glass via Hyprland blur → Task 2 (`hl.layer_rule` blur on `shell:power`). ✓
- Darker backdrop for focus (user's added requirement) → Task 3 (`color: "#66000000"`). ✓
- Custom SVG icons, recolored → Task 3 (`Image` + `MultiEffect` colorization, real Phosphor filenames). ✓
- Accent-blue selection → Task 1 palette (`wlogoutSelectedBorder`/`wlogoutIconSelected` = `#0A84FF`) consumed in Task 3. ✓
- New `whiteSur_dark` theme + activate it → Task 1 (new entry + `get: whiteSur_dark`). ✓
- New `wlogoutPanelBg`/`wlogoutPanelBorder` on ALL themes → Task 1 Steps 1–3. ✓
- Behavior/keybindings unchanged → Task 3 keeps keyboard/mouse block verbatim; Global Constraints. ✓
- `iconColor`/`iconPressedColor` values (spec flagged to verify against `Icon.qml`) → set to sensible `#DDFFFFFF`/`#0A84FF`; they drive bar icons, and Task 1 Step 6 verifies the bar renders without error. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"; every code step shows complete code. ✓

**Type/name consistency:** Property names (`wlogoutPanelBg`, `wlogoutPanelBorder`, `wlogout*`) identical across Task 1 definitions and Task 3 usage; namespace `shell:power` consistent between Task 2 match and Overlay. ✓
