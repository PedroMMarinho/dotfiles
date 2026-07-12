import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import "../"

BarBlock {
  id: root

  property int capacity: -1
  property string status: ""

  // WhiteSur (icon-theme) symbolic battery icon for the current charge/state.
  function batteryIcon() {
    if (capacity < 0)
      return "battery-missing-symbolic";
    const lvl = Math.max(0, Math.min(100, Math.round(capacity / 10) * 10));
    // WhiteSur names the full+charging icon "-charged-", not "-charging-";
    // requesting the nonexistent name would fall back to a junk icon.
    if (status === "Charging")
      return lvl >= 100 ? "battery-level-100-charged-symbolic"
                        : "battery-level-" + lvl + "-charging-symbolic";
    return "battery-level-" + lvl + "-symbolic";
  }

  content: Row {
    spacing: 4

    Item {
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: pctText.implicitWidth
      implicitHeight: pctText.implicitHeight

      Text {
        id: pctText
        anchors.centerIn: parent
        text: root.capacity >= 0 ? root.capacity + "%" : ""
        color: "white"
        font.family: "JetBrainsMono"
        font.pointSize: 12
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
        source: Quickshell.iconPath(root.batteryIcon())
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

  Process {
    id: batteryProc
    command: ["sh", "-c", "cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); st=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); echo \"$cap|$st\""]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const parts = data.split("|");
        const c = parseInt(parts[0]);
        root.capacity = isNaN(c) ? -1 : c;
        root.status = (parts[1] || "").trim();
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: batteryProc.running = true
  }
}
