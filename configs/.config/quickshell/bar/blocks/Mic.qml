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

  // Helper function to get the correct icon based on volume level
  function getVolumeIcon() {
    if (root.muted) return "audio-input-microphone-muted-symbolic";
    
    const vol = root.source?.audio?.volume ?? 0;
    if (vol <= 0.0) return "audio-input-microphone-muted-symbolic";
    if (vol < 0.33) return "audio-input-microphone-low-symbolic";
    if (vol < 0.66) return "audio-input-microphone-medium-symbolic";
    return "audio-input-microphone-high-symbolic";
  }

  content: Row {
    spacing: 6
    opacity: root.muted ? 0.5 : 1.0 

    Image {
      anchors.verticalCenter: parent.verticalCenter
      width: 16
      height: 16
      
      // Standard FreeDesktop icon names for microphones
      source: Quickshell.iconPath(root.muted ? "audio-input-microphone-muted-symbolic" : root.getVolumeIcon())
      
      // Ensures SVGs render crisply
      sourceSize.width: width
      sourceSize.height: height
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.volume
      color: "white" // Adjust this to match your bar's theme
      font.pointSize: 10
    }
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