import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/"

// A dropdown anchored under a bar block. Owns the focus-grab lifecycle so
// consumers only set `popupOpen` and supply `contentComponent`.
Item {
  id: root

  // The bar block this popup hangs beneath.
  required property Item anchorItem
  // Two-way: set to open/close; also cleared by click-outside.
  property bool popupOpen: false
  // The popup body.
  required property Component contentComponent
  property int implicitContentWidth: 280

  function close() { root.popupOpen = false; }

  // Keep the global open-popup count in step, including on destruction, so the
  // bar never gets stuck holding keyboard focus.
  onPopupOpenChanged: {
    Globals.openPopups += root.popupOpen ? 1 : -1;
    if (!root.popupOpen)
      grabTimer.armed = false;
  }
  Component.onDestruction: {
    if (root.popupOpen)
      Globals.openPopups -= 1;
  }

  PopupWindow {
    id: win
    visible: root.popupOpen
    color: "transparent"
    implicitWidth: root.implicitContentWidth
    implicitHeight: bodyLoader.implicitHeight + 16

    // These bindings evaluate before the anchor item is parented into a window,
    // so `anchor.window` is null on first pass. Guard both — an unguarded read
    // throws a TypeError every re-evaluation and the popup mispositions.
    anchor {
      window: root.anchorItem.QsWindow.window
      rect.y: anchor.window ? anchor.window.implicitHeight + 3 : 0
      rect.x: anchor.window
        ? anchor.window.contentItem
            .mapFromItem(root.anchorItem, root.anchorItem.width / 2, 0).x
        : 0
      edges: Edges.Top
      gravity: Edges.Bottom
    }

    // A focus grab requested in the same frame the surface is created is
    // silently rejected — grab.active stays false and keystrokes go to whatever
    // was focused before. interval:0 is also wrong: the grab activates and
    // immediately fires `cleared`, closing the popup. 150ms is the verified
    // working value; `grab.active` is the diagnostic if this ever regresses.
    Timer {
      id: grabTimer
      property bool armed: false
      interval: 150
      running: root.popupOpen
      onTriggered: armed = true
    }

    HyprlandFocusGrab {
      id: grab
      windows: [win]
      active: root.popupOpen && grabTimer.armed
      onCleared: root.popupOpen = false
    }

    Rectangle {
      anchors.fill: parent
      radius: 8
      color: Theme.get.wlogoutPanelBg
      border.width: 1
      border.color: Theme.get.wlogoutPanelBorder

      // Do NOT anchors.fill here: the window's implicitHeight is derived from
      // this Loader, so filling the window makes height depend on itself and
      // the popup collapses to nothing. Width is driven from the fixed window
      // width; height flows up from the content.
      Loader {
        id: bodyLoader
        x: 8
        y: 8
        width: parent.width - 16
        sourceComponent: root.contentComponent
        active: root.popupOpen
      }
    }
  }
}
