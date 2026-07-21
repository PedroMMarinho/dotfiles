import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
  id: root
  Layout.preferredWidth: contentContainer.implicitWidth + 10
  Layout.preferredHeight: 30

  property Item content
  property Item mouseArea: mouseArea

  property string text
  property bool dim: false
  property var onClicked: function() {}
  // Optional: function(steps) called on scroll, steps = wheel notches (+up/-down)
  property var onScrolled
  property int contentZ: 0

  property string hoveredBgColor: "#666666"
  property bool hovered: hoverHandler.hovered

  // Background color
  color: {
    if (hovered)
      return hoveredBgColor;
    return "transparent";
  }

  Behavior on color {
    ColorAnimation {
      duration: 200
    }
  }

  Item {
    // Contents of the bar block
    id: contentContainer
    implicitWidth:  content.implicitWidth
    implicitHeight: content.implicitHeight
    anchors.centerIn: parent
    children: content
    // Opt-in: raise content above decorations declared at the use site (hover
    // overlays) that would otherwise paint over it.  Defaults to the original
    // stacking so existing blocks are unaffected.
    z: root.contentZ
  }

  // BarText renders RichText, and a Text item doing so accepts hover events
  // itself, so MouseArea.containsMouse never turns true over any text in the
  // block.  A HoverHandler still sees the event regardless of the children.
  HoverHandler {
    id: hoverHandler
  }

  MouseArea {
    id: mouseArea
    anchors.fill: root
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onClicked: root.onClicked()

    onWheel: event => {
      if (root.onScrolled)
        root.onScrolled(event.angleDelta.y / 120);
      else
        event.accepted = false;
    }
  }

}
