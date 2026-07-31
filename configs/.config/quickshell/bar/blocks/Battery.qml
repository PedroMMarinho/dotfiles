import QtQuick
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import "../"
import "root:/battery" as BatteryService

// View only. Polling and notifications belong to the singleton, since this
// block is instantiated once per screen.
BarBlock {
  id: root

  readonly property int capacity: BatteryService.Controller.capacity
  readonly property string status: BatteryService.Controller.status

  content: Row {
    spacing: 8

    Item {
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: pctText.implicitWidth
      implicitHeight: pctText.implicitHeight

      Text {
        id: pctText
        anchors.centerIn: parent
        text: root.capacity >= 0 ? root.capacity + "%" : ""
        color: "white"
        font.pointSize: 10
      }

      DropShadow {
        anchors.fill: parent
        horizontalOffset: 1
        verticalOffset: 1
        color: "#000000"
        source: pctText
      }
    }

    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      height: 20

      IconImage {
        id: iconImg
        anchors.fill: parent
        source: Quickshell.iconPath(BatteryService.Controller.icon)
        implicitSize: 20
        mipmap: true
      }

      DropShadow {
        anchors.fill: parent
        horizontalOffset: 1
        verticalOffset: 1
        radius: 8.0
        color: "#000000"
        source: iconImg
      }
    }
  }
}
