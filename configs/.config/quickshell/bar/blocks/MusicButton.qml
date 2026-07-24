import QtQuick

Item {
  id: root

  property string glyph
  property string label
  property bool active: true

  signal activated()

  implicitWidth: 18
  implicitHeight: 18
  opacity: root.active ? 1.0 : 0.35

  Accessible.role: Accessible.Button
  Accessible.name: root.label
  Accessible.onPressAction: root.activated()

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: mouseArea.containsMouse && root.active ? "#33FFFFFF" : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }
  }

  Text {
    anchors.centerIn: parent
    text: root.glyph
    color: "white"
    font.family: "JetBrainsMono Nerd Font Propo"
    font.pointSize: 8
  }

  // A MouseArea rather than a TapHandler: it consumes the press outright, so a
  // click on a transport button never also reaches the BarBlock underneath.
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    onClicked: {
      if (root.active)
        root.activated();
    }
  }
}
