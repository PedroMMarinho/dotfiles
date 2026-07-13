import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../"

BarBlock {
  id: root
  visible: Pipewire.ready

  property PwNode source: Pipewire.defaultAudioSource
  readonly property bool muted: source?.audio?.muted ?? false
  property string volume: Pipewire.ready && source?.audio ? `${Math.round(source.audio.volume * 100)}%` : ""

  content: BarText {
    symbolText: root.muted ? `󰍭 ${root.volume}` : `󰍬 ${root.volume}`
    dim: root.muted
  }

  // Click toggles mute on the default input.
  onClicked: function() {
    if (root.source?.audio)
      root.source.audio.muted = !root.source.audio.muted;
  }

  // Scroll on the block adjusts the microphone volume in 5% steps.
  onScrolled: function(steps) {
    if (!root.source?.audio)
      return;
    root.source.audio.volume = Math.max(0, Math.min(1, root.source.audio.volume + steps * 0.05));
  }

  PwObjectTracker { objects: [ source ] }
}
