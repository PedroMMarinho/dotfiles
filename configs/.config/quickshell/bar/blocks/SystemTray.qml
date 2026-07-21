import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/bar"

RowLayout {
  id: root
  spacing: 2

  // Single source of truth: drives both the clip width and the arrow rotation.
  property bool expanded: false

  // Hide the whole block (arrow included) when there are no tray items, so we
  // never present a dead toggle for an empty tray.
  visible: trayRepeater.count > 0

  // Clip container — width animates 0 <-> full. The icon row inside is anchored
  // to the RIGHT edge so icons retract toward the arrow as it collapses.
  Item {
    id: trayClip
    clip: true
    Layout.fillHeight: true
    Layout.preferredWidth: root.expanded ? iconRow.implicitWidth : 0

    Behavior on Layout.preferredWidth {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    RowLayout {
      id: iconRow
      spacing: 5
      height: parent.height
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter

      Repeater {
        id: trayRepeater
        model: ScriptModel {
          readonly property var hiddenIds: ["nm-applet", "blueman", "Fcitx"]
          values: [...SystemTray.items.values]
            .filter(i => hiddenIds.indexOf(i.id) === -1)
        }

        MouseArea {
          id: delegate
          required property SystemTrayItem modelData
          property alias item: delegate.modelData

          Layout.fillHeight: true
          implicitWidth: icon.implicitWidth + 5

          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          hoverEnabled: true

          onClicked: event => {
            if (event.button == Qt.LeftButton) {
              item.activate();
            } else if (event.button == Qt.MiddleButton) {
              item.secondaryActivate();
            } else if (event.button == Qt.RightButton) {
              menuAnchor.open();
            }
          }

          onWheel: event => {
            event.accepted = true;
            const points = event.angleDelta.y / 120
            item.scroll(points, false);
          }

          IconImage {
            id: icon
            anchors.centerIn: parent
            source: item.icon
            implicitSize: 16
          }

          QsMenuAnchor {
            id: menuAnchor
            menu: item.menu

            anchor.window: delegate.QsWindow.window
            anchor.adjustment: PopupAdjustment.Flip

            anchor.onAnchoring: {
              const window = delegate.QsWindow.window;
              const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, delegate.height);

              menuAnchor.anchor.rect = widgetRect;
            }
          }

          Tooltip {
            relativeItem: delegate.containsMouse ? delegate : null

            Label {
              text: delegate.item.tooltipTitle || delegate.item.id
            }
          }
        }
      }
    }
  }

  // Arrow toggle — reuses BarBlock for hover highlight + click + sizing.
  BarBlock {
    id: arrowBlock
    onClicked: function() { root.expanded = !root.expanded; }

    content: Item {
      implicitWidth: 16
      implicitHeight: 16

      IconImage {
        id: arrowIcon
        anchors.centerIn: parent
        implicitSize: 16
        source: Quickshell.iconPath("arrow-down-tiny-symbolic")

        rotation: root.expanded ? 90 : 0

        Behavior on rotation {
          NumberAnimation { 
            duration: 200 
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}