import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../"

BarBlock {
  id: root
  visible: Pipewire.ready

  property PwNode sink: Pipewire.defaultAudioSink
  readonly property bool muted: sink?.audio?.muted ?? false
  property string volume: Pipewire.ready && sink?.audio ? `${Math.round(sink.audio.volume * 100)}%` : ""

  content: BarText {
    symbolText: root.muted ? `󰝟 ${root.volume}` : ` ${root.volume}`
    dim: root.muted
  }

  // Click toggles mute on the default output.
  onClicked: function() {
    if (root.sink?.audio)
      root.sink.audio.muted = !root.sink.audio.muted;
  }

  // Scroll on the block adjusts the output volume in 5% steps.
  onScrolled: function(steps) {
    if (!root.sink?.audio)
      return;
    root.sink.audio.volume = Math.max(0, Math.min(1.2, root.sink.audio.volume + steps * 0.05));
  }

  PwObjectTracker { objects: [ sink ] }
}
