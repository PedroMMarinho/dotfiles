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

  // Helper function to get the correct icon based on volume level
  function getVolumeIcon() {
    if (root.muted) return "audio-volume-muted-symbolic";
    
    const vol = root.sink?.audio?.volume ?? 0;
    if (vol <= 0.0) return "audio-volume-muted-symbolic";
    if (vol < 0.33) return "audio-volume-low-symbolic";
    if (vol < 0.66) return "audio-volume-medium-symbolic";
    if (vol < 1.0) return "audio-volume-high-symbolic";
    return "audio-volume-overamplified-symbolic";
  }

  content: Row {
    spacing: 6
    opacity: root.muted ? 0.5 : 1.0

    Image {
      anchors.verticalCenter: parent.verticalCenter
      width: 16
      height: 16
      
      // Standard FreeDesktop icon names for audio output
      source: Quickshell.iconPath(root.getVolumeIcon())
      
      sourceSize.width: width
      sourceSize.height: height
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.volume
      color: "white" 
      font.pointSize: 10
    }
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