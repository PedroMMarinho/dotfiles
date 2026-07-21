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
