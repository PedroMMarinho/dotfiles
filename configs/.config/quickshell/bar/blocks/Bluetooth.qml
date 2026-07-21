import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import Quickshell.Services.SystemTray 
import "../"

BarBlock {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter

  readonly property var connectedDevices: [...Bluetooth.devices.values]
    .filter(d => d.connected)

  readonly property bool radioOn: root.adapter ? root.adapter.enabled : false

  // Show the battery of the first connected device that reports one.
  readonly property var batteryDevice: root.connectedDevices
    .find(d => d.batteryAvailable) ?? null

  // Find the bluetooth applet in the background tray
  readonly property var btApplet: {
    const trayItems = [...SystemTray.items.values];
    return trayItems.find(item => {
      const id = (item.id || "").toLowerCase();
      // Matches standard bluetooth applets like blueman or blueberry
      return id.includes("blueman") || id.includes("bluetooth");
    });
  }

  content: Item {
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Row {
      id: layout
      spacing: 5
      opacity: root.radioOn ? 1.0 : 0.5

      IconImage {
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 16
        source: Quickshell.iconPath(root.radioOn
          ? (root.connectedDevices.length > 0 ? "bluetooth-paired-symbolic"
                                              : "bluetooth-active-symbolic")
          : "bluetooth-disabled-symbolic")
      }
    }

    // Overlay MouseArea to catch both left and right clicks
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      
      onClicked: event => {
        if (!root.btApplet) {
          console.warn("Bluetooth applet not found! Make sure blueman-applet is running in the background.");
          return;
        }

        // Open the native blueman menu regardless of left or right click
        menuAnchor.open();
      }
    }
  }

  // Anchor to display the hidden blueman context menu
  QsMenuAnchor {
    id: menuAnchor
    menu: root.btApplet ? root.btApplet.menu : null

    anchor.window: root.QsWindow.window
    anchor.adjustment: PopupAdjustment.Flip

    anchor.onAnchoring: {
      const window = root.QsWindow.window;
      // Position the menu perfectly underneath the widget
      const widgetRect = window.contentItem.mapFromItem(root, 0, root.height, root.width, root.height);
      menuAnchor.anchor.rect = widgetRect;
    }
  }
}