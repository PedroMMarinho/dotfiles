import QtQuick

// Fixed-width label that scrolls its content when it does not fit, wrapping
// around through a second copy so the loop has no visible jump.
Item {
  id: root

  property string text
  property color color: "white"
  property real pointSize: 9
  property string fontFamily: "JetBrainsMono"
  // Blank run between the tail and the repeated head while scrolling.
  property int gap: 28
  // Scroll speed in pixels per second.
  property real speed: 6
  // Pause on the start of the line before each pass.
  property int startDelay: 1500
  // Freezes the scroll where it stands instead of stopping it, which would
  // rewind to the start of the line.
  property bool frozen: false

  readonly property bool scrolling: label.implicitWidth > root.width

  implicitHeight: label.implicitHeight
  clip: true

  Row {
    id: strip
    spacing: root.gap

    Text {
      id: label
      text: root.text
      color: root.color
      font.family: root.fontFamily
      font.pointSize: root.pointSize
    }

    Text {
      visible: root.scrolling
      text: label.text
      color: label.color
      font: label.font
    }
  }

  SequentialAnimation {
    id: cycle

    running: root.scrolling && root.visible
    loops: Animation.Infinite

    onRunningChanged: {
      if (!cycle.running)
        strip.x = 0;
    }

    // `paused` may only be written while the animation is running, so it goes
    // through a guarded Binding rather than a plain one.
    Binding on paused {
      value: root.frozen
      when: cycle.running
      restoreMode: Binding.RestoreNone
    }

    PauseAnimation {
      duration: root.startDelay
    }

    NumberAnimation {
      target: strip
      property: "x"
      from: 0
      // One copy plus the gap lands the second copy exactly where the first
      // started, so restarting at 0 is invisible.
      to: -(label.width + root.gap)
      duration: Math.max(1, (label.width + root.gap) / root.speed * 1000)
    }
  }
}
