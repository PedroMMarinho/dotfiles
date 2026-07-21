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
