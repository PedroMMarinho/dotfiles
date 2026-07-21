import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Widgets
import Quickshell.Services.SystemTray 
import "../"

BarBlock {
  id: root

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

  // Find the network applet in the background tray
  readonly property var networkApplet: {
    const trayItems = [...SystemTray.items.values];
    return trayItems.find(item => {
      const id = (item.id || "").toLowerCase();
      return id.includes("nm-applet") || id.includes("network");
    });
  }

  function wifiIcon() {
    if (!root.radioOn)
      return "network-wireless-disabled-symbolic";
    if (!root.activeNetwork)
      return "network-wireless-offline-symbolic";
    const s = root.activeNetwork.signalStrength;
    if (s == 0.0) return "network-wireless-connected-00";
    if (s < 0.25) return "network-wireless-connected-25";
    if (s < 0.50) return "network-wireless-connected-50";
    if (s < 0.75) return "network-wireless-connected-75";
    return "network-wireless-connected-100";
  }

  content: Item {
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Row {
      id: layout
      spacing: 6
      opacity: root.radioOn ? 1.0 : 0.5

      IconImage {
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 16
        source: Quickshell.iconPath(root.wifiIcon())
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      
      onClicked: event => {
        if (!root.networkApplet) {
          console.warn("Network applet not found! Make sure nm-applet is running.");
          return;
        }

        menuAnchor.open();
      }
    }
  }

  // Anchor to display the hidden nm-applet context menu
  QsMenuAnchor {
    id: menuAnchor
    menu: root.networkApplet ? root.networkApplet.menu : null

    anchor.window: root.QsWindow.window
    anchor.adjustment: PopupAdjustment.Flip

    anchor.onAnchoring: {
      const window = root.QsWindow.window;
      const widgetRect = window.contentItem.mapFromItem(root, 0, root.height, root.width, root.height);
      menuAnchor.anchor.rect = widgetRect;
    }
  }
}