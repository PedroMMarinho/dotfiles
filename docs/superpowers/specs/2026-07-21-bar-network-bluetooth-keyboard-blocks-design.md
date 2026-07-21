# Bar: WiFi, Bluetooth and Keyboard-layout blocks

**Date:** 2026-07-21
**Status:** Approved design, not yet implemented

## Goal

Add three new blocks to the right-hand side of the Quickshell bar, next to the
Clock:

1. **WiFi** — indicator plus a dropdown for scanning and connecting to networks.
2. **Bluetooth** — indicator plus a dropdown for connecting/pairing devices.
3. **Keyboard** — current fcitx5 input method, shown as a country flag.

Re-enable the system tray with `nm-applet` and `blueman` filtered out, so the
tray shows application icons only.

## Spike findings

A throwaway spike (`ShellRoot` + `PanelWindow` + `PopupWindow`, driven with
`wtype` and captured with `grim`) settled four questions that materially shape
the design. All four were verified on this machine, not assumed.

### 1. Popup keyboard focus needs two things, not one

The WiFi PSK field requires real keyboard input into a `PopupWindow`. Two
separate mechanisms both have to be right:

- **`WlrLayershell.keyboardFocus`** — `OnDemand` grants focus only on click, so
  a popup opened programmatically never receives keys. The bar escalates to
  `Exclusive` *only while a popup is open* and drops straight back to `OnDemand`
  when it closes, so the bar never holds the keyboard during normal use.
- **`HyprlandFocusGrab`** — must be armed **after** the popup surface is mapped.
  Requesting a grab in the same frame the surface is created is silently
  rejected (`grab.active` stays `false` and keystrokes go to whatever window was
  previously focused).

Measured arming behaviour:

| Arming delay | Result |
|---|---|
| none (bound directly to `visible`) | `grab=false`, no input received |
| `Timer { interval: 0 }` | grab activates then immediately fires `cleared` — popup closes itself |
| `Timer { interval: 150 }` | `grab=true`, input received, popup stays open |
| `Timer { interval: 1200 }` | works, but 1.2 s of dead popup is unacceptable UX |

**Decision:** arm the grab on a `Timer { interval: 150 }` gated on
`popup.visible`. Diagnose with `grab.active` if this regresses.

Note the spike opened the popup programmatically. Real usage opens it from a
click, which already gives the bar focus, so this is the pessimistic path — the
150 ms arm should be safe or better in practice.

### 2. Flag emoji render correctly

`Noto Color Emoji` is installed and carries all six regional-indicator
codepoints (U+1F1FA/F8, U+1F1F5/F9, U+1F1E8/F3). 🇺🇸 🇵🇹 🇨🇳 render as full-colour
flags in a plain QML `Text`, verified by screenshot. No new dependency needed.

Flag icon packs are **not** in the Arch official repos; SVG flags would require
AUR or vendoring from `circle-flags`/`flag-icons`. Not needed given the above.

### 3. fcitx5 emits no signal on input-method switch

Monitoring the session bus with `dbus-monitor --session "sender='org.fcitx.Fcitx5'"`
while switching to `keyboard-pt` and back produced **no** signal.
`CurrentInputMethod` is a DBus *method*, not a property, so `PropertiesChanged`
does not cover it either.

**Decision:** poll `fcitx5-remote -n` on a timer, following the existing
`Battery.qml` `Process` + `Timer` pattern. It returns the raw IM name
(`keyboard-us`) instantly.

### 4. Tray applet identities are clean

| Applet | SNI `Id` | `Title` | Object path |
|---|---|---|---|
| nm-applet | `nm-applet` | Network | `/org/ayatana/NotificationItem/nm_applet` |
| blueman | `blueman` | blueman | `/org/blueman/sni` |

Both have unique, stable `Id`s. The caveat in the existing `SystemTray.qml`
comment — that Electron apps all report `chrome_status_icon_1`, so filtering
must use `tooltipTitle` — **does not apply to these two**. Filter on `id`.

## Data sources

Native Quickshell 0.3.0 modules. No `nmcli`/`bluetoothctl` scraping.

- **`Quickshell.Networking`** — `Networking.wifiEnabled` (writable),
  `Networking.devices` → `WifiDevice`, `WifiNetwork.signalStrength` / `.security`,
  `Network.connected` / `.known` / `.state`, `connectWithPsk()`, `forget()`
- **`Quickshell.Bluetooth`** — `Bluetooth.defaultAdapter.enabled` / `.discovering`,
  `Bluetooth.devices` → `.connected` / `.paired` / `.battery` / `.icon`,
  `connect()` / `disconnect()` / `pair()` / `forget()`
- **fcitx5** — `fcitx5-remote -n` (polled)

Icons resolve through `Quickshell.iconPath()` with symbolic names, matching the
approach already used in `Battery.qml`:
`network-wireless-signal-{none,weak,ok,good,excellent}-symbolic`,
`bluetooth-{active,disabled}-symbolic`.

## Architecture

```
bar/BlockPopup.qml               reusable anchored dropdown
bar/blocks/Wifi.qml              indicator + popup content
bar/blocks/Bluetooth.qml         indicator + popup content
bar/blocks/Keyboard.qml          fcitx5 flag indicator
bar/blocks/wifi/NetworkRow.qml   one SSID row
bar/blocks/bluetooth/DeviceRow.qml  one device row
```

`BlockPopup.qml` is the shared abstraction: anchored `PopupWindow`, the
150 ms-armed `HyprlandFocusGrab`, click-outside dismissal via `onCleared`, the
header-with-toggle, and a scrollable list slot. Both popups are the same shell
differing only in list content. This keeps `Wifi.qml` and `Bluetooth.qml` small
and focused on their own data binding.

The bar itself gains one change: dynamic `WlrLayershell.keyboardFocus`, driven
by whether any block popup is open. This is tracked through the existing
`Globals.popupContext` singleton so only one popup is open at a time — the same
mechanism `Tooltip.qml` already uses.

### Why anchored dropdowns rather than the Controller/Overlay pattern

The existing `launcher/`, `wallpaper/` and `power/` modules use a fullscreen
`PanelWindow` overlay with `keyboardFocus: Exclusive`. That pattern suits modal,
whole-screen interactions. These blocks are quick glance-and-click dropdowns
that should not dim the screen, so they use `PopupWindow` anchored under the
block instead. `Tooltip.qml` already establishes the anchored-popup precedent in
this codebase.

## Block behaviour

### WiFi
- **Indicator:** signal-strength icon from the connected network; distinct icon
  when the radio is off.
- **Popup:** header with an on/off switch bound to `Networking.wifiEnabled`;
  list of networks sorted by signal strength, connected one pinned first with a
  check; click a known network to connect, an unknown secured one to reveal the
  PSK field; a rescan control.
- **Scanning is gated on popup visibility** — `WifiDevice.scannerEnabled` is on
  only while the popup is open. Constant background scanning costs battery.

### Bluetooth
- **Indicator:** adapter-state icon; shows connected-device battery when
  `batteryAvailable`.
- **Popup:** header switch bound to `defaultAdapter.enabled`; paired devices
  first, then discovered ones; connect/disconnect/forget per row.
- **Discovery is gated on popup visibility**, same reasoning as WiFi scanning.
- **Pairing prompts still come from `blueman-applet`.** The Quickshell 0.3.0
  Bluetooth API exposes `pair()`/`cancelPair()` but **no pairing agent** —
  nothing to render a passkey-confirmation dialog. `blueman-applet` keeps
  running (hidden from the tray, not killed) so its agent continues to service
  those prompts. This is the reason the applets are filtered rather than
  disabled.

### Keyboard
- Polls `fcitx5-remote -n`; maps IM name to flag:

  | fcitx5 IM | Display |
  |---|---|
  | `keyboard-us` | 🇺🇸 |
  | `keyboard-pt` | 🇵🇹 |
  | `pinyin` | 🇨🇳 |

- Unknown IMs fall back to the raw name rather than a blank block, so adding a
  layout later degrades visibly instead of silently.
- Click cycles to the next input method.

## System tray

Uncomment `Blocks.SystemTray {}` at `Bar.qml:101` and filter the `ScriptModel`:

```qml
values: [...SystemTray.items.values].filter(
  i => i.id !== "nm-applet" && i.id !== "blueman"
)
```

The existing comment about `chrome_status_icon_1` stays — it remains true for
Electron apps and explains why `id` filtering is not universally safe. It gets
an amendment noting that these two applets do have unique ids.

## Final bar layout

```
Sound  Mic  [Tray: apps only]  Keyboard  WiFi  BT  Battery  Clock
```

## Testing

Quickshell has no unit-test harness here, so verification is manual and
observational, consistent with how the rest of this config is developed:

1. Config loads with no QML errors (`qs` log clean on reload).
2. Tray shows application icons; no network or bluetooth icon present.
3. WiFi popup opens, lists networks, connects to a known network.
4. PSK field accepts typed input (the spike's `grab=true` path).
5. Clicking outside dismisses each popup; bar does not retain keyboard focus
   afterwards — verify typing still reaches the focused application.
6. Keyboard block tracks IM switches within one poll interval.
7. Scanning stops when popups close (`scannerEnabled`/`discovering` both false).

## Risks and open items

- **Bar keyboard-focus escalation** is the main behavioural risk. If `Exclusive`
  while a popup is open causes focus-stealing problems in practice, the fallback
  is routing PSK entry through a fullscreen overlay like `launcher/Overlay.qml`.
- **The 150 ms grab-arming delay is empirical**, not a documented guarantee. If
  a future Quickshell or Hyprland release changes surface-mapping timing, the
  symptom will be a popup that closes itself immediately or ignores keys;
  `grab.active` is the diagnostic.
- **Pinyin's 🇨🇳 flag is semantically loose** — pinyin is an input method, not a
  country layout. Accepted deliberately for visual consistency with the other
  two; `拼` is the alternative if it grates.
