# WiFi, Bluetooth and Keyboard Bar Blocks — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add WiFi, Bluetooth and fcitx5 keyboard-layout blocks to the right side of the Quickshell bar, and re-enable the system tray with the `nm-applet` and `blueman` icons filtered out.

**Architecture:** Three new `BarBlock` subclasses in `bar/blocks/`. WiFi and Bluetooth share a single reusable anchored dropdown, `bar/BlockPopup.qml`, which owns the `HyprlandFocusGrab` lifecycle and click-outside dismissal. The bar escalates its layershell keyboard focus only while a popup is open. Data comes from the native `Quickshell.Networking` and `Quickshell.Bluetooth` singletons; the keyboard block polls `fcitx5-remote`.

**Tech Stack:** Quickshell 0.3.0, Qt 6 / QML, Hyprland (wlr-layershell + hyprland-focus-grab), NetworkManager via `Quickshell.Networking`, BlueZ via `Quickshell.Bluetooth`, fcitx5 via `fcitx5-remote` + `busctl`.

**Spec:** `docs/superpowers/specs/2026-07-21-bar-network-bluetooth-keyboard-blocks-design.md`

## Global Constraints

These apply to every task. They are empirical findings from the spike — violating
any of them produces silent, hard-to-diagnose failure, not an error message.

- **Never sample `Networking` / `Bluetooth` once.** Both singletons are lazily
  initialised and populate asynchronously over DBus. Reading them in
  `Component.onCompleted` returns `devices.length === 0`, `wifiEnabled === false`,
  `defaultAdapter === null` even when the hardware is up. Data lands ~1s after the
  first *live declarative binding*. Always bind; never read imperatively at startup.
- **`ObjectModel.values` is not a JS array.** `Array.isArray(...)` is `false`. Spread
  it before using array methods: `[...Networking.devices.values]`. This matches the
  existing `SystemTray.qml` usage.
- **`HyprlandFocusGrab` must be armed after the popup surface maps.** Binding
  `active` directly to `visible` is silently rejected (`grab.active` stays `false`).
  `Timer { interval: 0 }` activates then immediately fires `cleared`, closing the
  popup. Use `Timer { interval: 150 }`. Verified working value.
- **The bar must escalate `WlrLayershell.keyboardFocus` to `Exclusive` only while a
  popup is open**, dropping back to `OnDemand` otherwise. `OnDemand` alone grants
  focus only on click, so a text field in a popup receives nothing.
- **`WifiNetwork.signalStrength` is a `double` in the range 0.0–1.0**, not 0–100.
  Observed: `0.65`.
- **Existing style:** 2-space indent, `id: root` on the block root, `content:` for
  the block body, `Quickshell.iconPath()` for symbolic icons, `color: "white"`,
  `font.pointSize: 10` for block text. Match `Sound.qml` / `Battery.qml`.

### Verified enum values

```
DeviceType:            None=0, Wifi=1, Wired=2
ConnectionState:       Unknown=0, Connecting=1, Connected=2, Disconnecting=3, Disconnected=4
WifiSecurityType:      Wpa3SuiteB192=0, Sae=1, Wpa2Eap=2, Wpa2Psk=3, WpaEap=4, WpaPsk=5,
                       StaticWep=6, DynamicWep=7, Leap=8, Owe=9, Open=10, Unknown=11
BluetoothAdapterState: Disabled=0, Enabled=1, Enabling=2, Disabling=3, Blocked=4
BluetoothDeviceState:  Disconnected=0, Connected=1, Disconnecting=2, Connecting=3
```

Reference them by name in QML (`DeviceType.Wifi`, `WifiSecurityType.Open`), not by number.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/qs-check.sh` | Create — load config in an isolated instance, report QML errors |
| `configs/.config/quickshell/bar/BlockPopup.qml` | Create — reusable anchored dropdown, owns focus-grab lifecycle |
| `configs/.config/quickshell/bar/blocks/Keyboard.qml` | Create — fcitx5 flag indicator |
| `configs/.config/quickshell/bar/blocks/Wifi.qml` | Create — WiFi indicator + popup |
| `configs/.config/quickshell/bar/blocks/wifi/NetworkRow.qml` | Create — one SSID row |
| `configs/.config/quickshell/bar/blocks/Bluetooth.qml` | Create — BT indicator + popup |
| `configs/.config/quickshell/bar/blocks/bluetooth/DeviceRow.qml` | Create — one BT device row |
| `configs/.config/quickshell/bar/blocks/SystemTray.qml` | Modify — filter nm-applet + blueman |
| `configs/.config/quickshell/bar/Bar.qml` | Modify — add blocks, dynamic keyboardFocus |
| `configs/.config/quickshell/Globals.qml` | Modify — expose open-popup tracking |

---

### Task 1: Verification harness

There is no test framework for this config, and `qmllint` is unreliable here (it
exits 255 on both modified *and* baseline files — a tool configuration issue, not a
syntax signal). The only trustworthy check is loading the config in a real
Quickshell instance and inspecting the log. Every later task depends on this.

**Files:**
- Create: `scripts/qs-check.sh`

**Interfaces:**
- Produces: `scripts/qs-check.sh [config-path]` — exit 0 = clean load, exit 1 = QML errors printed to stdout.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Loads a Quickshell config in an isolated instance and reports QML errors.
# Exits 0 on a clean load, 1 if anything error-shaped appears in the log.
#
# Note: this spawns a *second* bar alongside the running one for a few seconds.
# It stacks below the real bar and disappears when the check finishes.
set -uo pipefail

CONFIG="${1:-$HOME/dotfiles/configs/.config/quickshell/shell.qml}"
SETTLE="${QS_CHECK_SETTLE:-6}"

if [[ ! -f "$CONFIG" ]]; then
  echo "qs-check: no such config: $CONFIG" >&2
  exit 1
fi

LOG="$(mktemp -t qs-check.XXXXXX.log)"
trap 'rm -f "$LOG"' EXIT

# setsid so the child is not in this shell's process group; we kill it by PID.
setsid quickshell -p "$CONFIG" >"$LOG" 2>&1 &
QS_PID=$!

sleep "$SETTLE"
kill "$QS_PID" 2>/dev/null
wait "$QS_PID" 2>/dev/null

# Strip ANSI colour, drop the INFO banner lines, then look for trouble.
ERRORS="$(sed 's/\x1b\[[0-9;]*m//g' "$LOG" \
  | grep -vE '^\s*INFO' \
  | grep -iE 'error|warning|is not a|is not defined|undefined|cannot|unable|failed|ReferenceError|TypeError')"

if [[ -n "$ERRORS" ]]; then
  echo "qs-check: FAIL — $CONFIG"
  echo "$ERRORS"
  exit 1
fi

echo "qs-check: OK — $CONFIG loaded clean"
exit 0
```

- [ ] **Step 2: Make it executable and run it against the current config**

```bash
chmod +x scripts/qs-check.sh
./scripts/qs-check.sh
```

Expected: `qs-check: OK — /home/marinho/dotfiles/configs/.config/quickshell/shell.qml loaded clean`

This establishes the baseline. If it fails *now*, the config was already broken —
fix that before continuing, since every later task uses this as its pass signal.

- [ ] **Step 3: Verify it actually catches an error**

A check that never fails is worthless. Introduce a deliberate fault, confirm the
harness reports it, then revert.

```bash
printf '\nItem { property int x: undefinedThing.y }\n' >> configs/.config/quickshell/bar/BarText.qml
./scripts/qs-check.sh; echo "exit=$?"
git checkout configs/.config/quickshell/bar/BarText.qml
```

Expected: `qs-check: FAIL` with a non-zero exit, then a clean `git status`.

- [ ] **Step 4: Commit**

```bash
git add scripts/qs-check.sh
git commit -m "Add qs-check harness for validating quickshell config loads"
```

---

### Task 2: Keyboard block

Simplest block, no popup, no shared dependencies — a good first real change that
exercises the harness end to end.

**Files:**
- Create: `configs/.config/quickshell/bar/blocks/Keyboard.qml`
- Modify: `configs/.config/quickshell/bar/Bar.qml`

**Interfaces:**
- Produces: `Blocks.Keyboard` — a `BarBlock` with no required properties.

- [ ] **Step 1: Write the block**

Create `configs/.config/quickshell/bar/blocks/Keyboard.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

BarBlock {
  id: root

  // fcitx5 emits no DBus signal when the input method changes — verified with
  // `dbus-monitor --session "sender='org.fcitx.Fcitx5'"` across a switch — and
  // CurrentInputMethod is a DBus *method*, not a property, so PropertiesChanged
  // does not cover it either. Polling is the only option.
  property string currentIm: ""

  // Ordered IM list for cycling, filled once from the active fcitx5 group.
  property var imList: []

  readonly property var flagFor: ({
    "keyboard-us": "🇺🇸",
    "keyboard-pt": "🇵🇹",
    "pinyin": "🇨🇳"
  })

  // Unknown IMs fall back to their raw name, so adding a layout later degrades
  // visibly instead of rendering an empty block.
  readonly property string label: root.flagFor[root.currentIm] ?? (root.currentIm || "…")

  content: Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: "white"
    // Colour emoji sit high on the line; nudge down so flags align with the
    // neighbouring text blocks.
    font.pointSize: 11
    y: 1
  }

  onClicked: function() {
    if (root.imList.length < 2)
      return;
    const i = root.imList.indexOf(root.currentIm);
    const next = root.imList[(i + 1) % root.imList.length];
    switchProc.command = ["fcitx5-remote", "-s", next];
    switchProc.running = true;
  }

  // Current input method, polled.
  Process {
    id: pollProc
    command: ["fcitx5-remote", "-n"]
    running: true
    stdout: SplitParser {
      onRead: data => root.currentIm = data.trim()
    }
  }

  Timer {
    interval: 400
    running: true
    repeat: true
    onTriggered: pollProc.running = true
  }

  // The IM list for the active group, read once at startup. Emits one name per
  // line; see the design doc for the token layout this parses.
  Process {
    id: listProc
    running: true
    command: ["sh", "-c",
      "busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 " +
      "InputMethodGroupInfo s \"$(fcitx5-remote -q)\" " +
      "| tr ' ' '\\n' | grep '\"' | tr -d '\"' | tail -n +2 | awk 'NR%2==1'"]
    stdout: SplitParser {
      onRead: data => {
        const name = data.trim();
        if (name.length > 0 && root.imList.indexOf(name) === -1)
          root.imList = [...root.imList, name];
      }
    }
  }

  Process { id: switchProc }
}
```

- [ ] **Step 2: Add it to the bar**

In `configs/.config/quickshell/bar/Bar.qml`, inside the `rightBlocks` `RowLayout`,
add `Blocks.Keyboard {}` before `Blocks.Battery {}`:

```qml
          Blocks.Sound {}
          Blocks.Mic {}
          //Blocks.SystemTray {}
          Blocks.Keyboard {}
          Blocks.Battery {}
          Blocks.Clock {
            Layout.rightMargin: 8
          }
```

- [ ] **Step 3: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 4: Verify behaviour against the live bar**

Reload the running shell and confirm the flag appears and tracks switches:

```bash
touch configs/.config/quickshell/bar/Bar.qml
sleep 2
fcitx5-remote -n                       # note current, e.g. keyboard-us
fcitx5-remote -s keyboard-pt && sleep 1 && fcitx5-remote -n
```

Expected: block shows 🇺🇸, then 🇵🇹 within ~400ms of the switch. Restore with
`fcitx5-remote -s keyboard-us`.

- [ ] **Step 5: Commit**

```bash
git add configs/.config/quickshell/bar/blocks/Keyboard.qml configs/.config/quickshell/bar/Bar.qml
git commit -m "Add fcitx5 keyboard layout block with flag indicators"
```

---

### Task 3: Popup-tracking in Globals

The bar needs to know whether *any* block popup is open so it can escalate keyboard
focus. `Globals.popupContext` already tracks a single active popup for tooltips;
this adds an explicit open-popup counter that `BlockPopup` maintains.

**Files:**
- Modify: `configs/.config/quickshell/Globals.qml`

**Interfaces:**
- Produces: `Globals.openPopups` (int), `Globals.anyPopupOpen` (bool, readonly).

- [ ] **Step 1: Extend the singleton**

Replace the contents of `configs/.config/quickshell/Globals.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell

Singleton {
  // Shared popup context so only one tooltip/popup is active at a time.
  readonly property PopupContext popupContext: PopupContext {}

  // Number of BlockPopups currently open. The bar escalates its layershell
  // keyboard focus while this is non-zero — a popup with a text field cannot
  // receive keys otherwise. Maintained by BlockPopup.qml.
  property int openPopups: 0
  readonly property bool anyPopupOpen: openPopups > 0
}
```

- [ ] **Step 2: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 3: Commit**

```bash
git add configs/.config/quickshell/Globals.qml
git commit -m "Track open block popups in Globals for keyboard focus escalation"
```

---

### Task 4: Bar keyboard-focus escalation

**Files:**
- Modify: `configs/.config/quickshell/bar/Bar.qml`

**Interfaces:**
- Consumes: `Globals.anyPopupOpen` from Task 3.

- [ ] **Step 1: Add the import and the focus binding**

In `configs/.config/quickshell/bar/Bar.qml`, add the Wayland import alongside the
existing imports:

```qml
import Quickshell.Wayland
```

Then inside `PanelWindow`, directly after `color: Theme.get.barBgColor`, add:

```qml
      // A popup with a text field cannot receive keystrokes unless the parent
      // layershell surface accepts keyboard focus. OnDemand only grants focus on
      // click, so escalate to Exclusive while a popup is open and drop straight
      // back afterwards — the bar must never hold the keyboard during normal use.
      WlrLayershell.keyboardFocus: Globals.anyPopupOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand
```

`Globals` is already reachable via the existing `import "root:/"`.

- [ ] **Step 2: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 3: Verify the bar does not steal keyboard focus at rest**

No popup exists yet, so `anyPopupOpen` is always false and the bar should behave
exactly as before.

```bash
touch configs/.config/quickshell/bar/Bar.qml
sleep 2
```

Then type into any application. Expected: typing works normally; the bar takes no
keyboard focus.

- [ ] **Step 4: Commit**

```bash
git add configs/.config/quickshell/bar/Bar.qml
git commit -m "Escalate bar keyboard focus while a block popup is open"
```

---

### Task 5: BlockPopup — the shared anchored dropdown

The riskiest component. It encapsulates the two focus mechanisms and the
grab-arming delay so that `Wifi.qml` and `Bluetooth.qml` never have to think
about them.

**Files:**
- Create: `configs/.config/quickshell/bar/BlockPopup.qml`

**Interfaces:**
- Consumes: `Globals.openPopups` (Task 3).
- Produces: `BlockPopup` with properties `anchorItem: Item`, `popupOpen: bool`,
  `contentComponent: Component`, `implicitContentWidth: int`; method `close()`.

- [ ] **Step 1: Write the component**

Create `configs/.config/quickshell/bar/BlockPopup.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/"

// A dropdown anchored under a bar block. Owns the focus-grab lifecycle so
// consumers only set `popupOpen` and supply `contentComponent`.
Item {
  id: root

  // The bar block this popup hangs beneath.
  required property Item anchorItem
  // Two-way: set to open/close; also cleared by click-outside.
  property bool popupOpen: false
  // The popup body.
  required property Component contentComponent
  property int implicitContentWidth: 280

  function close() { root.popupOpen = false; }

  // Keep the global open-popup count in step, including on destruction, so the
  // bar never gets stuck holding keyboard focus.
  onPopupOpenChanged: {
    Globals.openPopups += root.popupOpen ? 1 : -1;
    if (!root.popupOpen)
      grabTimer.armed = false;
  }
  Component.onDestruction: {
    if (root.popupOpen)
      Globals.openPopups -= 1;
  }

  PopupWindow {
    id: win
    visible: root.popupOpen
    color: "transparent"
    implicitWidth: root.implicitContentWidth
    implicitHeight: bodyLoader.implicitHeight + 16

    anchor {
      window: root.anchorItem.QsWindow.window
      rect.y: anchor.window.implicitHeight + 3
      rect.x: anchor.window.contentItem
        .mapFromItem(root.anchorItem, root.anchorItem.width / 2, 0).x
      edges: Edges.Top
      gravity: Edges.Bottom
    }

    // A focus grab requested in the same frame the surface is created is
    // silently rejected — grab.active stays false and keystrokes go to whatever
    // was focused before. interval:0 is also wrong: the grab activates and
    // immediately fires `cleared`, closing the popup. 150ms is the verified
    // working value; `grab.active` is the diagnostic if this ever regresses.
    Timer {
      id: grabTimer
      property bool armed: false
      interval: 150
      running: root.popupOpen
      onTriggered: armed = true
    }

    HyprlandFocusGrab {
      id: grab
      windows: [win]
      active: root.popupOpen && grabTimer.armed
      onCleared: root.popupOpen = false
    }

    Rectangle {
      anchors.fill: parent
      radius: 8
      color: Theme.get.wlogoutPanelBg
      border.width: 1
      border.color: Theme.get.wlogoutPanelBorder

      Loader {
        id: bodyLoader
        anchors.fill: parent
        anchors.margins: 8
        sourceComponent: root.contentComponent
        active: root.popupOpen
      }
    }
  }
}
```

- [ ] **Step 2: Verify it loads clean**

Nothing instantiates it yet, but a syntax or import error still surfaces.

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 3: Commit**

```bash
git add configs/.config/quickshell/bar/BlockPopup.qml
git commit -m "Add reusable anchored BlockPopup with focus-grab lifecycle"
```

---

### Task 6: WiFi block — indicator only

Indicator first, popup second, so a rendering problem is never tangled with a
focus problem.

**Files:**
- Create: `configs/.config/quickshell/bar/blocks/Wifi.qml`
- Modify: `configs/.config/quickshell/bar/Bar.qml`

**Interfaces:**
- Produces: `Blocks.Wifi`; internally exposes `wifiDevice` (`WifiDevice | null`)
  and `activeNetwork` (`WifiNetwork | null`) for Task 7.

- [ ] **Step 1: Write the indicator**

Create `configs/.config/quickshell/bar/blocks/Wifi.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Widgets
import "../"

BarBlock {
  id: root

  // These MUST stay declarative bindings. Networking is lazily initialised and
  // populates ~1s after its first live binding; reading it imperatively at
  // startup yields an empty model and a permanently wrong indicator.
  readonly property var wifiDevice: {
    const devs = [...Networking.devices.values];
    return devs.find(d => d.type === DeviceType.Wifi) ?? null;
  }

  readonly property var activeNetwork: {
    if (!root.wifiDevice)
      return null;
    const nets = [...root.wifiDevice.networks.values];
    return nets.find(n => n.connected) ?? null;
  }

  readonly property bool radioOn: Networking.wifiEnabled

  // signalStrength is a 0.0–1.0 double, not a percentage. Verified: 0.65.
  function wifiIcon() {
    if (!root.radioOn)
      return "network-wireless-disabled-symbolic";
    if (!root.activeNetwork)
      return "network-wireless-signal-none-symbolic";
    const s = root.activeNetwork.signalStrength;
    if (s < 0.25) return "network-wireless-signal-weak-symbolic";
    if (s < 0.50) return "network-wireless-signal-ok-symbolic";
    if (s < 0.75) return "network-wireless-signal-good-symbolic";
    return "network-wireless-signal-excellent-symbolic";
  }

  content: Row {
    spacing: 6
    opacity: root.radioOn ? 1.0 : 0.5

    IconImage {
      anchors.verticalCenter: parent.verticalCenter
      implicitSize: 16
      source: Quickshell.iconPath(root.wifiIcon())
    }
  }
}
```

- [ ] **Step 2: Add it to the bar**

In `rightBlocks`, between `Blocks.Keyboard {}` and `Blocks.Battery {}`:

```qml
          Blocks.Keyboard {}
          Blocks.Wifi {}
          Blocks.Battery {}
```

- [ ] **Step 3: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 4: Verify the indicator reflects real state**

```bash
touch configs/.config/quickshell/bar/Bar.qml
sleep 3
nmcli -t -f ACTIVE,SSID,SIGNAL device wifi | grep '^yes'
```

Expected: a wifi icon appears, filled proportionally to the reported signal. The
icon must appear within a couple of seconds of reload — if it stays on the
"none" glyph, a binding has been broken into an imperative read.

- [ ] **Step 5: Commit**

```bash
git add configs/.config/quickshell/bar/blocks/Wifi.qml configs/.config/quickshell/bar/Bar.qml
git commit -m "Add WiFi indicator block"
```

---

### Task 7: WiFi popup — network list and PSK entry

**Files:**
- Create: `configs/.config/quickshell/bar/blocks/wifi/NetworkRow.qml`
- Modify: `configs/.config/quickshell/bar/blocks/Wifi.qml`

**Interfaces:**
- Consumes: `BlockPopup` (Task 5), `wifiDevice`/`activeNetwork` (Task 6).
- Produces: `NetworkRow` with properties `network` (`WifiNetwork`),
  `expanded` (bool); signals `activated()`, `pskSubmitted(string psk)`.

- [ ] **Step 1: Write the row component**

Create `configs/.config/quickshell/bar/blocks/wifi/NetworkRow.qml`:

```qml
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Widgets

// One SSID row. Reveals a password field when an unknown secured network is
// selected. Purely presentational — the parent decides what to do on activate.
Item {
  id: row

  required property var network
  property bool expanded: false

  signal activated()
  signal pskSubmitted(string psk)

  // Owe (opportunistic wireless encryption) and Open need no passphrase.
  readonly property bool needsPsk: network.security !== WifiSecurityType.Open
                                && network.security !== WifiSecurityType.Owe

  implicitWidth: parent ? parent.width : 260
  implicitHeight: col.implicitHeight + 8

  Rectangle {
    anchors.fill: parent
    radius: 5
    color: hover.hovered ? "#22FFFFFF" : "transparent"
    HoverHandler { id: hover }
    MouseArea {
      anchors.fill: parent
      onClicked: row.activated()
    }
  }

  Column {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    spacing: 4

    Row {
      spacing: 8
      width: parent.width

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: row.network.connected ? "✓" : (row.network.known ? "•" : " ")
        color: row.network.connected ? "#30D158" : "#888888"
        font.pointSize: 9
        width: 10
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: row.network.name
        color: "white"
        font.pointSize: 9
        elide: Text.ElideRight
        width: parent.width - 70
      }

      IconImage {
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 14
        source: Quickshell.iconPath(
          row.network.signalStrength < 0.25 ? "network-wireless-signal-weak-symbolic"
          : row.network.signalStrength < 0.50 ? "network-wireless-signal-ok-symbolic"
          : row.network.signalStrength < 0.75 ? "network-wireless-signal-good-symbolic"
          : "network-wireless-signal-excellent-symbolic")
      }
    }

    // Password entry, revealed only for unknown secured networks.
    Row {
      visible: row.expanded && row.needsPsk && !row.network.known
      spacing: 6
      width: parent.width

      TextField {
        id: pskField
        width: parent.width - 60
        placeholderText: "password"
        echoMode: TextInput.Password
        color: "white"
        font.pointSize: 9
        background: Rectangle { color: "#2C2C2E"; radius: 4 }
        onAccepted: row.pskSubmitted(text)
        // The popup arms its focus grab 150ms after opening; focus here is
        // requested by the parent once the row expands.
      }

      Rectangle {
        width: 50
        height: pskField.height
        radius: 4
        color: "#0A84FF"
        Text {
          anchors.centerIn: parent
          text: "join"; color: "white"; font.pointSize: 9
        }
        MouseArea {
          anchors.fill: parent
          onClicked: row.pskSubmitted(pskField.text)
        }
      }
    }
  }

  onExpandedChanged: if (expanded && needsPsk && !network.known) pskField.forceActiveFocus()
}
```

- [ ] **Step 2: Wire the popup into the WiFi block**

In `configs/.config/quickshell/bar/blocks/Wifi.qml`, add these imports at the top:

```qml
import QtQuick.Controls
import "wifi" as WifiUi
```

Then add inside the `BarBlock`, after the `content:` block:

```qml
  property string expandedSsid: ""

  onClicked: function() { popup.popupOpen = !popup.popupOpen; }

  // Scanning is gated on popup visibility — continuous background scanning
  // costs battery for data nobody is looking at.
  Binding {
    target: root.wifiDevice
    property: "scannerEnabled"
    value: popup.popupOpen
    when: root.wifiDevice !== null
  }

  BlockPopup {
    id: popup
    anchorItem: root
    implicitContentWidth: 300

    contentComponent: Component {
      Column {
        spacing: 6
        width: parent.width

        Row {
          width: parent.width
          Text {
            text: "Wi-Fi"
            color: "white"
            font.pointSize: 10
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
          Item { width: parent.width - 100; height: 1 }
          Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = checked
          }
        }

        Rectangle { width: parent.width; height: 1; color: "#33FFFFFF" }

        // Connected first, then strongest. Spread required: `values` is not
        // a JS array.
        Repeater {
          model: {
            if (!root.wifiDevice)
              return [];
            return [...root.wifiDevice.networks.values].sort((a, b) => {
              if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
              return b.signalStrength - a.signalStrength;
            });
          }

          WifiUi.NetworkRow {
            required property var modelData
            width: parent.width
            network: modelData
            expanded: root.expandedSsid === modelData.name

            onActivated: {
              if (modelData.connected)
                return;
              if (modelData.known || !needsPsk)
                modelData.connectWithSettings();
              else
                root.expandedSsid = modelData.name;
            }

            onPskSubmitted: psk => {
              modelData.connectWithPsk(psk);
              root.expandedSsid = "";
            }
          }
        }
      }
    }
  }
```

- [ ] **Step 3: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 4: Verify the popup opens, scans, and takes keyboard input**

```bash
touch configs/.config/quickshell/bar/Bar.qml
sleep 3
```

Then, by hand:
1. Click the WiFi block. Expected: dropdown opens, connected network pinned at
   top with a green `✓`, other SSIDs appearing within ~2s as the scan populates.
2. Click an unknown secured network. Expected: password field appears **and takes
   typed input**. This is the spike's `grab=true` path — if typing does nothing,
   check `grab.active` in `BlockPopup.qml`.
3. Press Escape or click outside. Expected: popup closes.
4. Type into another application. Expected: keystrokes go there, not the bar.

- [ ] **Step 5: Verify scanning stops when closed**

```bash
sleep 5 && nmcli device wifi list --rescan no | wc -l
```

Expected: the block's `scannerEnabled` follows `popup.popupOpen`. With the popup
closed the network list should stop refreshing.

- [ ] **Step 6: Commit**

```bash
git add configs/.config/quickshell/bar/blocks/wifi/NetworkRow.qml configs/.config/quickshell/bar/blocks/Wifi.qml
git commit -m "Add WiFi popup with network list and password entry"
```

---

### Task 8: Bluetooth block — indicator only

**Files:**
- Create: `configs/.config/quickshell/bar/blocks/Bluetooth.qml`
- Modify: `configs/.config/quickshell/bar/Bar.qml`

**Interfaces:**
- Produces: `Blocks.Bluetooth`; internally exposes `adapter` and
  `connectedDevices` for Task 9.

- [ ] **Step 1: Write the indicator**

Create `configs/.config/quickshell/bar/blocks/Bluetooth.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import "../"

BarBlock {
  id: root

  // Declarative, for the same lazy-init reason as Wifi.qml. `defaultAdapter` is
  // null for roughly the first second after startup.
  readonly property var adapter: Bluetooth.defaultAdapter

  readonly property var connectedDevices: [...Bluetooth.devices.values]
    .filter(d => d.connected)

  readonly property bool radioOn: root.adapter ? root.adapter.enabled : false

  // Show the battery of the first connected device that reports one.
  readonly property var batteryDevice: root.connectedDevices
    .find(d => d.batteryAvailable) ?? null

  content: Row {
    spacing: 5
    opacity: root.radioOn ? 1.0 : 0.5

    IconImage {
      anchors.verticalCenter: parent.verticalCenter
      implicitSize: 16
      source: Quickshell.iconPath(root.radioOn
        ? (root.connectedDevices.length > 0 ? "bluetooth-active-symbolic"
                                            : "bluetooth-symbolic")
        : "bluetooth-disabled-symbolic")
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.batteryDevice !== null
      text: root.batteryDevice
        ? Math.round(root.batteryDevice.battery * 100) + "%"
        : ""
      color: "white"
      font.pointSize: 10
    }
  }
}
```

- [ ] **Step 2: Add it to the bar**

In `rightBlocks`, between `Blocks.Wifi {}` and `Blocks.Battery {}`:

```qml
          Blocks.Wifi {}
          Blocks.Bluetooth {}
          Blocks.Battery {}
```

- [ ] **Step 3: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 4: Verify against real adapter state**

```bash
touch configs/.config/quickshell/bar/Bar.qml
sleep 3
bluetoothctl show | grep -E "Powered|Name"
bluetoothctl devices Connected
```

Expected: icon reflects powered state; with nothing connected it shows the plain
bluetooth glyph, not the "active" one.

- [ ] **Step 5: Commit**

```bash
git add configs/.config/quickshell/bar/blocks/Bluetooth.qml configs/.config/quickshell/bar/Bar.qml
git commit -m "Add Bluetooth indicator block"
```

---

### Task 9: Bluetooth popup — device list

**Files:**
- Create: `configs/.config/quickshell/bar/blocks/bluetooth/DeviceRow.qml`
- Modify: `configs/.config/quickshell/bar/blocks/Bluetooth.qml`

**Interfaces:**
- Consumes: `BlockPopup` (Task 5), `adapter` (Task 8).
- Produces: `DeviceRow` with property `device` (`BluetoothDevice`); signals
  `toggleConnect()`, `forgetRequested()`.

- [ ] **Step 1: Write the row component**

Create `configs/.config/quickshell/bar/blocks/bluetooth/DeviceRow.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets

// One Bluetooth device row. Presentational; the parent performs the action.
Item {
  id: row

  required property var device

  signal toggleConnect()
  signal forgetRequested()

  implicitWidth: parent ? parent.width : 260
  implicitHeight: 30

  Rectangle {
    anchors.fill: parent
    radius: 5
    color: hover.hovered ? "#22FFFFFF" : "transparent"
    HoverHandler { id: hover }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: event => {
        if (event.button === Qt.RightButton)
          row.forgetRequested();
        else
          row.toggleConnect();
      }
    }
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    spacing: 8

    // BlueZ supplies a freedesktop icon name directly, e.g. "audio-headset".
    IconImage {
      anchors.verticalCenter: parent.verticalCenter
      implicitSize: 16
      source: Quickshell.iconPath(row.device.icon || "bluetooth-symbolic")
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: row.device.name || row.device.address
      color: "white"
      font.pointSize: 9
      elide: Text.ElideRight
      width: parent.width - 110
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: {
        if (row.device.state === BluetoothDeviceState.Connecting) return "…";
        if (row.device.connected)
          return row.device.batteryAvailable
            ? Math.round(row.device.battery * 100) + "%"
            : "connected";
        return row.device.paired ? "paired" : "";
      }
      color: row.device.connected ? "#30D158" : "#888888"
      font.pointSize: 8
    }
  }
}
```

- [ ] **Step 2: Wire the popup into the Bluetooth block**

In `configs/.config/quickshell/bar/blocks/Bluetooth.qml`, add these imports:

```qml
import QtQuick.Controls
import "bluetooth" as BtUi
```

Then add inside the `BarBlock`, after the `content:` block:

```qml
  onClicked: function() { popup.popupOpen = !popup.popupOpen; }

  // Discovery only while the popup is open — scanning is power-hungry.
  Binding {
    target: root.adapter
    property: "discovering"
    value: popup.popupOpen
    when: root.adapter !== null && root.adapter.enabled
  }

  BlockPopup {
    id: popup
    anchorItem: root
    implicitContentWidth: 300

    contentComponent: Component {
      Column {
        spacing: 6
        width: parent.width

        Row {
          width: parent.width
          Text {
            text: "Bluetooth"
            color: "white"
            font.pointSize: 10
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
          Item { width: parent.width - 130; height: 1 }
          Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.adapter ? root.adapter.enabled : false
            enabled: root.adapter !== null
            onToggled: if (root.adapter) root.adapter.enabled = checked
          }
        }

        Rectangle { width: parent.width; height: 1; color: "#33FFFFFF" }

        Text {
          visible: root.adapter === null
          text: "No Bluetooth adapter"
          color: "#888888"
          font.pointSize: 9
        }

        // Connected first, then paired, then discovered.
        Repeater {
          model: [...Bluetooth.devices.values].sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return (a.name || "").localeCompare(b.name || "");
          })

          BtUi.DeviceRow {
            required property var modelData
            width: parent.width
            device: modelData

            // `connected` is a writable property on BluetoothDevice; prefer it
            // over any `connect` method, which collides with QML's own signal
            // connect() and is not in the type's declared method list.
            onToggleConnect: modelData.connected = !modelData.connected

            onForgetRequested: if (modelData.paired) modelData.forget()
          }
        }

        Text {
          text: "right-click a device to forget it"
          color: "#666666"
          font.pointSize: 7
        }
      }
    }
  }
```

- [ ] **Step 3: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 4: Verify against a real device**

```bash
touch configs/.config/quickshell/bar/Bar.qml
sleep 3
bluetoothctl devices
```

By hand: click the Bluetooth block. Expected: paired devices listed (the
`WH-CH720N` headset should appear with an `audio-headset` icon). Click it and
confirm it connects; the row should show `connected` and the block icon should
switch to the "active" glyph.

- [ ] **Step 5: Commit**

```bash
git add configs/.config/quickshell/bar/blocks/bluetooth/DeviceRow.qml configs/.config/quickshell/bar/blocks/Bluetooth.qml
git commit -m "Add Bluetooth popup with device list"
```

---

### Task 10: Re-enable the system tray, filtered

**Files:**
- Modify: `configs/.config/quickshell/bar/blocks/SystemTray.qml:12-18`
- Modify: `configs/.config/quickshell/bar/Bar.qml`

**Interfaces:**
- Consumes: nothing from earlier tasks.

- [ ] **Step 1: Filter the tray model**

In `configs/.config/quickshell/bar/blocks/SystemTray.qml`, replace the
`ScriptModel` block (lines 12–18) with:

```qml
  Repeater {
    model: ScriptModel {
      // Note: don't filter on item.id == "chrome_status_icon_1" here — every
      // Electron app (Discord, WhatsApp, ...) reports that same generic id.
      // To hide a specific app, filter on item.tooltipTitle instead.
      //
      // nm-applet and blueman are the exception: both report unique, stable
      // ids (verified over DBus), so filtering them by id is safe. They are
      // hidden rather than killed — blueman-applet still supplies the BlueZ
      // pairing agent that renders passkey prompts, which Quickshell's
      // Bluetooth API does not provide.
      readonly property var hiddenIds: ["nm-applet", "blueman"]
      values: [...SystemTray.items.values]
        .filter(i => hiddenIds.indexOf(i.id) === -1)
    }
```

- [ ] **Step 2: Uncomment the tray in the bar**

In `configs/.config/quickshell/bar/Bar.qml`, replace `//Blocks.SystemTray {}` with
`Blocks.SystemTray {}`, so `rightBlocks` reads:

```qml
          Blocks.Sound {}
          Blocks.Mic {}
          Blocks.SystemTray {}
          Blocks.Keyboard {}
          Blocks.Wifi {}
          Blocks.Bluetooth {}
          Blocks.Battery {}
          Blocks.Clock {
            Layout.rightMargin: 8
          }
```

- [ ] **Step 3: Verify it loads clean**

Run: `./scripts/qs-check.sh`
Expected: `qs-check: OK`

- [ ] **Step 4: Verify the applets are hidden but still running**

```bash
touch configs/.config/quickshell/bar/Bar.qml
sleep 3
pgrep -a nm-applet | head -1
pgrep -a blueman-applet | head -1
busctl --user get-property :1.5 /org/ayatana/NotificationItem/nm_applet org.kde.StatusNotifierItem Id
```

Expected: both processes still running (the pairing agent depends on it), the
tray shows application icons only, and **no** network or bluetooth icon appears
in the tray.

- [ ] **Step 5: Commit**

```bash
git add configs/.config/quickshell/bar/blocks/SystemTray.qml configs/.config/quickshell/bar/Bar.qml
git commit -m "Re-enable system tray with nm-applet and blueman filtered out"
```

---

### Task 11: Full-system verification

A final pass over the behaviours that only break when everything is present at
once — particularly focus, which is global state.

**Files:**
- Modify: none expected. Fix regressions in place if found.

- [ ] **Step 1: Cold-start the shell**

```bash
./scripts/qs-check.sh
```

Expected: `qs-check: OK`.

- [ ] **Step 2: Verify cold-start population**

Restart the real shell and watch the first few seconds — this is where the lazy
init constraint bites.

```bash
pkill -x qs; sleep 1; (setsid qs >/dev/null 2>&1 &); sleep 5
```

Expected: within ~2s of the bar appearing, the WiFi icon shows real signal
strength and the Bluetooth icon reflects adapter state. Neither may remain stuck
on the "none"/"disabled" glyph — that is the signature of an imperative read.

- [ ] **Step 3: Verify focus is released**

1. Open the WiFi popup, type in the password field, press Escape.
2. Immediately type into a terminal.

Expected: keystrokes reach the terminal. If the bar keeps focus, `Globals.openPopups`
has drifted — check the increment/decrement pairing in `BlockPopup.qml`.

- [ ] **Step 4: Verify only one popup at a time**

Open the WiFi popup, then click the Bluetooth block.

Expected: WiFi closes as Bluetooth opens (the focus grab clears it). `openPopups`
must return to 0 when both are closed.

- [ ] **Step 5: Verify scanning is gated**

```bash
sleep 10; bluetoothctl show | grep Discovering
```

Expected: `Discovering: no` while the Bluetooth popup is closed.

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "Fix issues found in full-system verification"
```

---

## Self-Review Notes

**Spec coverage:** All spec sections map to tasks — spike findings → Global
Constraints; data sources → Tasks 6/8; architecture → Tasks 5/6/8; block
behaviour → Tasks 2/7/9; system tray → Task 10; testing → Tasks 1 and 11.

**Deliberate deviation from TDD:** This codebase has no test harness and QML UI
behaviour here is not unit-testable. Task 1 substitutes an automated load-error
check, and each task pairs it with explicit manual verification steps. Task 1
Step 3 verifies the harness itself can fail, so it is not a rubber stamp.

**Known-uncertain points**, flagged for the implementer rather than papered over:

- `Network.connectWithSettings()` is called with no arguments in Task 7. The
  qmltypes lists two overloads; the zero-argument form is assumed to connect with
  saved settings. If it errors, inspect the overload signature and pass the
  device's existing `nmSettings` entry.
- `Binding` on `scannerEnabled` / `discovering` targets an object that is `null`
  during the first second after startup, hence the `when:` guards. If the binding
  fails to apply after the device appears, replace it with an explicit
  `onPopupOpenChanged` handler.
- Icon names (`network-wireless-signal-*`, `bluetooth-*-symbolic`) follow the
  freedesktop spec, but the active theme is WhiteSur — `Battery.qml` already
  documents a case where WhiteSur diverges from the expected naming. If an icon
  renders blank, check the theme's actual filenames before assuming the code is
  wrong.
