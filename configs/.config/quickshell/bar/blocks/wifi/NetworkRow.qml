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

  // The popup arms its focus grab 150ms after opening; by the time a row can be
  // expanded the grab is live, so focusing here is safe.
  onExpandedChanged: if (expanded && needsPsk && !network.known) pskField.forceActiveFocus()
}
