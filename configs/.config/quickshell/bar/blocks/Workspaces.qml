import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import "root:/"
import "../"

RowLayout {
  spacing: 0
  property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

  Repeater {
    model: ScriptModel {
      values: {
        var seenEmpty = false
        return [...Hyprland.workspaces.values]
          .filter((ws) => {
            if (ws.monitor !== monitor || ws.name.includes("special"))
              return false

            // There is a flickering that can happen when switching from one
            // empty workspace to another where both empty workspaces are shown
            // on the bar at the same time.  This ensures that only the first
            // empty workspace is shown.
            const isNumeric = /^\d+$/.test(ws.name);
            if (!isNumeric)
              return true;
            if (!seenEmpty) {
              seenEmpty = true
              return true
            }
            return true;
          })
          // Sort workspaces by id
          .sort((a, b) => a.id - b.id)
      }
    }

    BarBlock {
      property HyprlandWorkspace ws: modelData
      property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === ws.id
      property bool isOpen: monitor.activeWorkspace?.id === ws.id

      dim: true
      border.color: Theme.get.buttonBorderColor
      radius: 5
      contentZ: 1
      gradient: isActive || isOpen ? Theme.get.buttonActiveGradient : Theme.get.buttonInactiveGradientV
      Layout.preferredWidth: content.width + 20

      Rectangle {
        visible: !isActive && !isOpen
        gradient: Theme.get.buttonInactiveGradientH
        implicitWidth: parent.width
        implicitHeight: parent.height
        radius: parent.radius
        z:-1
      }

      Rectangle {
        visible: Theme.get.buttonBorderShadow
        implicitWidth: parent.width - 1
        implicitHeight: parent.height - 1
        radius: parent.radius
        color: "transparent" // Transparent fill
        border.color: parent.isActive || parent.isOpen ? "transparent" : "black" // Inner border color
        border.width: 1 // Inner border width

        x: 1
        y: 1
        z: -1
      }

      // BarBlock's built-in hover colour is overridden by the gradient above,
      // so the hover state needs its own overlay on top of it.  The open
      // workspace already reads as highlighted, so it stays untouched.
      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "white"
        opacity: hovered && !isActive && !isOpen ? 0.15 : 0

        Behavior on opacity {
          NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
      }

      onClicked: function() {
        Hyprland.dispatch(`hl.dsp.focus({workspace = ${ws.id}})`);
      }

      content: RowLayout {
        spacing: 8
        anchors.centerIn: parent

        Item {
          Layout.alignment: Qt.AlignVCenter
          implicitWidth: wsNum.implicitWidth
          implicitHeight: wsNum.implicitHeight
          BarText {
            id: wsNum
            symbolText: `${ws.id}`
            dim: !isActive
          }
        }

        Repeater {
          model: ScriptModel {
            values: getClients(ws.id)
          }

          delegate: Item {
            required property var modelData
            property int symbolSize: 22
            property bool focused: !!modelData && !!modelData.focused && isActive
            property real fade: focused ? 1 : 0.65
            implicitWidth: symbolSize
            implicitHeight: symbolSize
            Layout.alignment: Qt.AlignCenter

            Behavior on fade {
              NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            IconImage {
              id: appIcon
              anchors.centerIn: parent
              source: Quickshell.iconPath(modelData.icon, "application-x-executable")
              implicitSize: parent.symbolSize
              opacity: parent.fade
              mipmap: true
            }
            DropShadow {
              anchors.fill: appIcon
              verticalOffset: 1
              horizontalOffset: 1
              radius: 8.0
              color: "#000000"
              source: appIcon
              opacity: parent.fade
            }
            Rectangle {
              visible: modelData.mult > 1
              anchors.top: parent.top
              anchors.right: parent.right
              width: 12
              height: width
              radius: width / 2
              color: "black"
              opacity: 0.8
              BarText {
                anchors.centerIn: parent
                symbolText: `${modelData.mult}`
                pointSize: 8
                dim: !focused
                style: Text.Outline
                styleColor: "black"
              }
            }
          }
        }
      }
    }
  }

  // Collect the live windows in a workspace, grouped by app class, and resolve
  // each to an icon-theme name via its desktop entry.  Reading
  // Hyprland.toplevels here keeps the ScriptModel reactive to window changes;
  // reading activeToplevel likewise re-runs this on every focus change.
  function getClients(wsId) {
    let groups = {}
    let order = []
    const active = Hyprland.activeToplevel
    for (let t of Hyprland.toplevels.values) {
      if (!t.workspace || t.workspace.id !== wsId)
        continue
      let cls = (t.lastIpcObject && t.lastIpcObject.class) || (t.wayland && t.wayland.appId) || ""
      if (cls === "")
        continue
      if (!(cls in groups)) {
        let entry = DesktopEntries.heuristicLookup(cls)
        if (!entry) {
          // Windows launched with a custom class (`kitty --class kitty-float`)
          // have no desktop entry of their own; retry on the base app name.
          let base = cls.replace(/-(float|floating|scratchpad)$/, "")
          if (base !== cls)
            entry = DesktopEntries.heuristicLookup(base)
        }
        groups[cls] = { icon: entry ? entry.icon : cls, mult: 0, focused: false }
        order.push(cls)
      }
      groups[cls].mult++
      // Windows of one class collapse into a single icon, so the group counts
      // as focused if any of its windows is.
      if (t === active)
        groups[cls].focused = true
    }
    return order.map(c => groups[c])
  }
}
