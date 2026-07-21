import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "blocks" as Blocks
import "root:/"


Scope {
  Variants {
    model: Quickshell.screens
  
    PanelWindow {
      id: bar
      property var modelData
      screen: modelData

      color: Theme.get.barBgColor

      // A popup with a text field cannot receive keystrokes unless the parent
      // layershell surface accepts keyboard focus. OnDemand only grants focus on
      // click, so escalate to Exclusive while a popup is open and drop straight
      // back afterwards — the bar must never hold the keyboard during normal use.
      WlrLayershell.keyboardFocus: Globals.anyPopupOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand

      Rectangle {
        id: highlight
        anchors.fill: parent
        gradient: Theme.get.barGradient
      }

      implicitHeight: 30

      visible: true

      IpcHandler {
        target: "bar"

        function toggleVis(): void {
          visible = !visible;
        }
      }
    
      anchors {
        top: Theme.get.onTop
        bottom: !Theme.get.onTop
        left: true
        right: true
      }
    
      RowLayout {
        id: allBlocks
        spacing: 0
        anchors.fill: parent
  
        // Left side
        RowLayout {
          id: leftBlocks
          spacing: 10
          Layout.alignment: Qt.AlignLeft
          Layout.fillWidth: true
          

          Blocks.Icon {}
          Blocks.Workspaces {}
        }
        
        Blocks.ActiveWorkspace {
          id: activeWorkspace
          Layout.leftMargin: 10
          anchors.centerIn: undefined
          font.pointSize: 10

          chopLength: {
            var space = Math.floor(bar.width - (rightBlocks.implicitWidth + leftBlocks.implicitWidth))
            return space * 0.08;
          }

          text: {
            var str = activeWindowTitle
            return str.length > chopLength ? str.slice(0, chopLength) + '...' : str;
          }

          color: {
            return Hyprland.focusedMonitor == Hyprland.monitorFor(screen)
              ? "#FFFFFF" : "#CCCCCC"
          }
        }


        // Without this filler item, the active window block will be centered
        // despite setting left alignment
        Item {
          Layout.fillWidth: true
        }
  
        // Right side
        RowLayout {
          id: rightBlocks
          spacing: 2
          Layout.alignment: Qt.AlignRight
          Layout.fillWidth: true

          Blocks.SystemTray {}
          Blocks.Sound {}
          Blocks.Mic {}
          Blocks.Keyboard {}
          Blocks.Battery {}
          Blocks.Wifi {}
          Blocks.Bluetooth {}
          Blocks.Clock {}
        }
      }
    }
  }
}