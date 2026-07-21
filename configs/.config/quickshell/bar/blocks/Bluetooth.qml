import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import "../"
import "bluetooth" as BtUi

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
}
