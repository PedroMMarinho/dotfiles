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
  property bool underline
  property var onClicked: function() {}
  // Optional: function(steps) called on scroll, steps = wheel notches (+up/-down)
  property var onScrolled
  property int leftPadding
  property int rightPadding

  property string hoveredBgColor: "#666666"

  // Background color
  color: {
    if (mouseArea.containsMouse)
      return hoveredBgColor;
    return "transparent";
  }

  states: [
    State {
      when: mouseArea.containsMouse
      PropertyChanges {
        target: root
      }
    }
  ]

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

  // While line underneath workspace
  Rectangle {
    id: wsLine
    width: parent.width
    height: 2

    color: {
      if (parent.underline)
        return "white";
      return "transparent";
    }
    anchors.bottom: parent.bottom
  }
}
