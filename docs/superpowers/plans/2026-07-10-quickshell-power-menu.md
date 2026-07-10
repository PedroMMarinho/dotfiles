# Quickshell Power Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. When writing QML, follow the `qt-development-skills:qt-qml` skill's best practices.

**Goal:** Add a Wlogout-style power menu to the Quickshell config with five actions (Lock, Logout, Suspend, Reboot, Shutdown), opened via Hyprland `mod + X`.

**Architecture:** A new `quickshell/power/` module mirroring the existing `launcher/` module — a `Controller.qml` singleton (IPC + LazyLoader) that lazily instantiates an `Overlay.qml` fullscreen dimmed PanelWindow holding a centered row of five buttons. Colors come from `Theme.get`. Hyprland triggers it through Quickshell IPC.

**Tech Stack:** QML (Qt 6 / Quickshell 0.3.0), Quickshell IPC, Hyprland Lua config.

## Global Constraints

- Quickshell version: 0.3.0 (Arch). Use APIs available in this version — the launcher module is the reference for what's supported (`PanelWindow`, `WlrLayershell`, `LazyLoader`, `IpcHandler`, `Quickshell.execDetached`, `ScriptModel`, `Repeater`).
- All shell commands run via `Quickshell.execDetached({ command: [argv...] })` with **argv arrays only** — no shell string interpolation.
- Colors must come from `Theme.get` (the active theme `Item`), never hardcoded, except the backdrop dim `#35000000` which matches the launcher convention.
- Follow the existing launcher module's file shape and QML style (2-space or tab indent matching neighboring files; `pragma Singleton` / `pragma ComponentBehavior: Bound` where the launcher uses them).
- IPC handler target name: `power`. Keybind calls `qs ipc call power toggle`.
- Working directory for all paths: `/home/marinho/dotfiles`.

**Verification note:** `qmllint` on Quickshell files emits import-resolution warnings (Quickshell modules aren't on the default QML path). Treat those specific warnings as expected noise — a task's `qmllint` step passes if it reports **no syntax errors** (unbalanced braces, unknown properties within resolved types, JS syntax errors). The authoritative check is the runtime reload in Task 6.

---

### Task 1: Add Wlogout theme colors to Theme.qml

Add power-menu color properties to **both** theme variants so theme switching stays consistent.

**Files:**
- Modify: `configs/.config/quickshell/Theme.qml`

**Interfaces:**
- Consumes: nothing.
- Produces: seven new properties on each theme `Item`, resolvable via `Theme.get.<name>`:
  - `wlogoutButtonBg` (string) — idle button fill
  - `wlogoutButtonBgHover` (string) — hovered/selected button fill
  - `wlogoutBorderColor` (string) — idle button border
  - `wlogoutSelectedBorder` (string) — selected/hovered button border (accent)
  - `wlogoutIconColor` (string) — glyph color idle
  - `wlogoutIconSelected` (string) — glyph color selected/hovered
  - `wlogoutLabelColor` (string) — text label color

- [ ] **Step 1: Add properties to the `black_flat` theme Item**

In `configs/.config/quickshell/Theme.qml`, inside the `Item { id: black_flat ... }` block, after the existing `iconPressedColor` line, add:

```qml
    // Wlogout power menu
    property string wlogoutButtonBg: "#22FFFFFF"
    property string wlogoutButtonBgHover: "#33FF55FF"
    property string wlogoutBorderColor: "#33FFFFFF"
    property string wlogoutSelectedBorder: "#FF55FF"
    property string wlogoutIconColor: "#DDFFFFFF"
    property string wlogoutIconSelected: "#FF55FF"
    property string wlogoutLabelColor: "#DDFFFFFF"
```

- [ ] **Step 2: Add the same properties to the `windowsXP` theme Item**

Inside the `Item { id: windowsXP ... }` block, after the existing `iconPressedColor` line, add:

```qml
    // Wlogout power menu
    property string wlogoutButtonBg: "#33FFFFFF"
    property string wlogoutButtonBgHover: "#66FFFFFF"
    property string wlogoutBorderColor: "#55FFFFFF"
    property string wlogoutSelectedBorder: "#FFD54F"
    property string wlogoutIconColor: "#FFFFFF"
    property string wlogoutIconSelected: "#FFD54F"
    property string wlogoutLabelColor: "#FFFFFF"
```

- [ ] **Step 3: Lint the file**

Run: `qmllint configs/.config/quickshell/Theme.qml`
Expected: no syntax errors (import warnings for `Quickshell` are expected noise).

- [ ] **Step 4: Commit**

```bash
git add configs/.config/quickshell/Theme.qml
git commit -m "feat(quickshell): add wlogout power-menu theme colors"
```

---

### Task 2: Create the Power Controller singleton

**Files:**
- Create: `configs/.config/quickshell/power/Controller.qml`

**Interfaces:**
- Consumes: nothing (Overlay is referenced by name; created in Task 3, but this file references `Overlay {}` which must exist to load at runtime — see Step 2 note).
- Produces:
  - Singleton `Controller` with `property bool isOpen`
  - `function init()` (no-op, called from shell.qml in Task 5)
  - IPC handler `target: "power"` with `open()`, `close()`, `toggle()`

- [ ] **Step 1: Create the Controller singleton**

Create `configs/.config/quickshell/power/Controller.qml`:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool isOpen: false

    IpcHandler {
        target: "power"

        function open() { root.isOpen = true; }
        function close() { root.isOpen = false; }
        function toggle() { root.isOpen = !root.isOpen; }
    }

    LazyLoader {
        active: root.isOpen
        Overlay {
            controller: root
        }
    }

    function init() {
    }
}
```

- [ ] **Step 2: Verify it references Overlay**

The `Overlay {}` type resolves to `Overlay.qml` in the same directory, created in Task 3. This file will not load standalone until Task 3 exists — that is expected. Do not lint-fail on the missing type here; proceed to Task 3, then lint both together.

- [ ] **Step 3: Commit**

```bash
git add configs/.config/quickshell/power/Controller.qml
git commit -m "feat(quickshell): add power menu controller singleton"
```

---

### Task 3: Create the Overlay UI and interaction

The core of the feature: dimmed fullscreen window, centered row of five buttons, keyboard + mouse interaction, commands.

**Files:**
- Create: `configs/.config/quickshell/power/Overlay.qml`

**Interfaces:**
- Consumes: `Theme.get.wlogout*` (Task 1); `required property var controller` (the Controller singleton from Task 2, exposes `isOpen`).
- Produces: the visible power menu. No outward API beyond being instantiated by the Controller's LazyLoader.

- [ ] **Step 1: Create the Overlay with actions model, layout, theming, and interaction**

Create `configs/.config/quickshell/power/Overlay.qml`:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/" // for Theme singleton

PanelWindow {
    id: root

    required property var controller

    // Five actions, left -> right. mnemonic = direct-activate key.
    readonly property var actions: [
        { label: "Lock",     glyph: "", mnemonic: "l", command: ["loginctl", "lock-session"] },
        { label: "Logout",   glyph: "", mnemonic: "e", command: ["hyprctl", "dispatch", "exit"] },
        { label: "Suspend",  glyph: "", mnemonic: "s", command: ["systemctl", "suspend"] },
        { label: "Reboot",   glyph: "", mnemonic: "r", command: ["systemctl", "reboot"] },
        { label: "Shutdown", glyph: "", mnemonic: "p", command: ["systemctl", "poweroff"] }
    ]

    property int selected: 0

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "#35000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "shell:power"

    function activate(index) {
        const action = root.actions[index];
        Quickshell.execDetached({ command: action.command });
        root.controller.isOpen = false;
    }

    // Click on the dim backdrop (outside buttons) closes the menu.
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

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 20

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: button
                    required property int index
                    required property var modelData

                    readonly property bool active: root.selected === index || hover.hovered

                    width: 110
                    height: 110
                    radius: 12
                    color: active ? Theme.get.wlogoutButtonBgHover : Theme.get.wlogoutButtonBg
                    border.width: 2
                    border.color: active ? Theme.get.wlogoutSelectedBorder : Theme.get.wlogoutBorderColor

                    HoverHandler {
                        id: hover
                        onHoveredChanged: if (hovered) root.selected = button.index
                    }

                    TapHandler {
                        onTapped: root.activate(button.index)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: button.modelData.glyph
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 36
                            color: button.active ? Theme.get.wlogoutIconSelected : Theme.get.wlogoutIconColor
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
```

Note on the Nerd Font family: the bar renders glyphs already; if `"Symbols Nerd Font"` does not resolve at runtime (glyphs show as boxes), replace with the exact family the bar uses — check `configs/.config/quickshell/bar/BarText.qml` / `blocks/Icon.qml` for the font family in use and match it. Adjust in Task 6 if needed.

- [ ] **Step 2: Lint both new module files together**

Run: `qmllint configs/.config/quickshell/power/Controller.qml configs/.config/quickshell/power/Overlay.qml`
Expected: no syntax errors. Import/type warnings for `Quickshell`, `Quickshell.Wayland`, and the `root:/` import are expected noise (Task 6 is the authoritative runtime check).

- [ ] **Step 3: Commit**

```bash
git add configs/.config/quickshell/power/Overlay.qml
git commit -m "feat(quickshell): add power menu overlay UI and interaction"
```

---

### Task 4: Wire the Controller into shell.qml

**Files:**
- Modify: `configs/.config/quickshell/shell.qml`

**Interfaces:**
- Consumes: `Power.Controller.init()` (Task 2).
- Produces: the power Controller singleton is initialized at shell startup so its IPC handler is registered.

- [ ] **Step 1: Add the power import and init call**

In `configs/.config/quickshell/shell.qml`, add the import alongside the launcher import and call `init()` in `Component.onCompleted`. The full file should read:

```qml
//@ pragma UseQApplication
import Quickshell
import QtQuick

import "launcher" as Launcher
import "bar" as Bar
import "power" as Power

ShellRoot {
        Bar.Bar {}
        Component.onCompleted: () => {
                Launcher.Controller.init();
                Power.Controller.init();
        }
}
```

- [ ] **Step 2: Lint the file**

Run: `qmllint configs/.config/quickshell/shell.qml`
Expected: no syntax errors (import warnings expected).

- [ ] **Step 3: Commit**

```bash
git add configs/.config/quickshell/shell.qml
git commit -m "feat(quickshell): register power controller at shell startup"
```

---

### Task 5: Bind mod + X in Hyprland

**Files:**
- Modify: `configs/.config/hypr/modules/keybinds.lua:49`

**Interfaces:**
- Consumes: the `power` IPC handler (Task 2).
- Produces: `mod + X` opens/closes the power menu.

- [ ] **Step 1: Replace the commented Wlogout keybind**

In `configs/.config/hypr/modules/keybinds.lua`, replace the commented line 49:

```lua
-- hl.bind(v.mainMod .. " + X", hl.dsp.exec_cmd(v.scriptsDir .. "/Wlogout.sh"))
```

with the active binding:

```lua
hl.bind(v.mainMod .. " + X", hl.dsp.exec_cmd("qs ipc call power toggle"))
```

- [ ] **Step 2: Commit**

```bash
git add configs/.config/hypr/modules/keybinds.lua
git commit -m "feat(hypr): bind mod+X to quickshell power menu"
```

---

### Task 6: Runtime verification

The authoritative end-to-end check. No new files — this validates the whole feature and captures any font/keybind fixes.

**Files:**
- Possibly modify: `configs/.config/quickshell/power/Overlay.qml` (font family only, if glyphs render as boxes).

- [ ] **Step 1: Restart Quickshell and reload Hyprland**

Run:
```bash
pkill qs; sleep 1; qs > /tmp/qs-power.log 2>&1 &
hyprctl reload
```
Expected: `qs` starts without fatal errors. Check `/tmp/qs-power.log` for QML errors referencing `power/` files — there should be none.

- [ ] **Step 2: Open the menu via IPC (proves the IPC path independent of the keybind)**

Run: `qs ipc call power toggle`
Expected: the dimmed power menu appears with five buttons (Lock, Logout, Suspend, Reboot, Shutdown), the first (Lock) highlighted. Run it again to confirm it toggles closed. If glyphs render as boxes, fix `font.family` in `Overlay.qml` to match the bar's Nerd Font family, save, and re-run Step 1.

- [ ] **Step 3: Verify keyboard + mouse interaction**

Open the menu, then confirm manually:
- Left/Right arrows move the highlight (wraps at ends).
- Enter activates the highlighted button (test with **Lock** — safe).
- Number keys 1–5 map to the five actions.
- Mnemonics `l e s r p` directly activate.
- Esc closes without acting.
- Mouse hover highlights; clicking the dim backdrop closes without acting.

Expected: all behave as described. **Lock** is the safe action to actually trigger; do not trigger Reboot/Shutdown/Logout during verification unless you intend the effect.

- [ ] **Step 4: Verify the keybind**

Press `mod + X`.
Expected: the menu opens. Press `mod + X` again (or Esc) — it closes.

- [ ] **Step 5: Commit any font/keybind fixes**

If Step 2 required a font-family fix:
```bash
git add configs/.config/quickshell/power/Overlay.qml
git commit -m "fix(quickshell): use correct nerd font family for power menu glyphs"
```
Otherwise, nothing to commit — verification complete.

---

## Self-Review

**Spec coverage:**
- New `power/` module (Controller + Overlay) → Tasks 2, 3. ✓
- Five actions with exact commands → Task 3 `actions` array (matches spec table). ✓
- `loginctl lock-session` for Lock, `hyprctl dispatch exit` for Logout → Task 3. ✓
- Dimmed fullscreen, exclusive keyboard, `shell:power` namespace, backdrop click-close → Task 3. ✓
- Arrows move / Enter / 1–5 / mnemonics `l e s r p` / Esc / hover / click → Task 3 Keys + handlers. ✓
- Wrap-around default → Task 3 uses modulo wrap. ✓
- Theming via `Theme.get` with new `wlogout*` props on both theme variants → Task 1. ✓
- `shell.qml` init → Task 4. ✓
- Hyprland `mod + X` → `qs ipc call power toggle` replacing line 49 → Task 5. ✓
- Testing/verification (qmllint + manual reload + Lock test) → per-task lint + Task 6. ✓

**Placeholder scan:** No TBD/TODO. The one conditional ("if glyphs render as boxes, match the bar's font family") is a concrete, bounded runtime fix with an explicit source to copy from, not a deferred decision.

**Type consistency:** `controller.isOpen` used in Overlay matches Controller's `property bool isOpen`. `Theme.get.wlogout*` names in Task 3 match the seven properties defined in Task 1 exactly. `activate(index)`, `selected`, `actions` used consistently within Overlay. IPC target `power` and `toggle` consistent across Tasks 2, 5, 6.
