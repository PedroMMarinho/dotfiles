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
