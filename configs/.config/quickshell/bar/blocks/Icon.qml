import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import "../"
import "root:/"

BarBlock {
  id: root
  Layout.preferredWidth: 45

  content: BarText {
    text: "" 
    pointSize: 17
    anchors.horizontalCenterOffset: -2
  }

  Image {
    anchors.fill: parent
    source: mouseArea.containsMouse
        ? "../images/" + Theme.get.iconPressedColor + ".png"
        : "../images/" + Theme.get.iconColor + ".png";
    visible: true
    z: -1
  }

  color: "transparent"

  Process {
    id: sysinfoTrigger
    running: false
    command: [
      "hyprctl", 
      "dispatch", 
      "hl.dsp.exec_cmd('[float] kitty --hold fastfetch')"
    ]
    stdout: SplitParser {
      onRead: data => console.log(`line read: ${data}`)
    }
  }

  onClicked: function() {
    sysinfoTrigger.running = true
  }
}