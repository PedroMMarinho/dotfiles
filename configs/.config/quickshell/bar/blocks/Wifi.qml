import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Widgets
import "../"
import "wifi" as WifiUi

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
      return "network-wireless-signal-offline-symbolic";
    const s = root.activeNetwork.signalStrength;
    if (s == 0.0) return "network-wireless-connected-00";
    if (s < 0.25) return "network-wireless-connected-25";
    if (s < 0.50) return "network-wireless-connected-50";
    if (s < 0.75) return "network-wireless-connected-75";
    return "network-wireless-connected-100";
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
}
