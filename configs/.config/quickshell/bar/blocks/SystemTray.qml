import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/bar"

RowLayout {
  spacing: 5

  Repeater {
    model: ScriptModel {
      // Note: don't filter on item.id == "chrome_status_icon_1" here — every
      // Electron app (Discord, WhatsApp, ...) reports that same generic id.
      // To hide a specific app, filter on item.tooltipTitle instead.
      //
      // nm-applet and blueman are the exception: both report unique, stable ids
      // (verified over DBus), so filtering them by id is safe. They are hidden
      // rather than killed — blueman-applet still supplies the BlueZ pairing
      // agent that renders passkey prompts, which Quickshell's Bluetooth API
      // does not provide.
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