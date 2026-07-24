import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../"
import "root:/"

BarBlock {
  id: root

  // Browsers register a player for every <video> on the page.  Their MPRIS
  // metadata carries no URL (Chrome publishes only title/artist/album), so
  // there is no way to ask "is this tab YouTube Music?" directly — the closest
  // signal is an album tag, which music services fill in and plain clips leave
  // empty.  Set false to let any browser audio through.
  property bool browserMusicOnly: true

  readonly property var browserBusNames: ["chrome", "chromium", "firefox", "brave", "vivaldi", "opera", "edge", "zen"]

  function isSpotify(candidate: MprisPlayer): bool {
    return candidate.dbusName.startsWith("org.mpris.MediaPlayer2.spotify") || candidate.desktopEntry === "spotify";
  }

  // playerctld mirrors whichever player is active, so it shows up as a second
  // copy of a real player and must never be picked.
  function isProxy(candidate: MprisPlayer): bool {
    return candidate.dbusName.startsWith("org.mpris.MediaPlayer2.playerctld");
  }

  function isBrowser(candidate: MprisPlayer): bool {
    const name = candidate.dbusName.toLowerCase();
    for (let i = 0; i < root.browserBusNames.length; ++i) {
      if (name.indexOf(root.browserBusNames[i]) !== -1)
        return true;
    }
    return false;
  }

  function isEligible(candidate: MprisPlayer): bool {
    if (root.isProxy(candidate))
      return false;
    if (root.browserMusicOnly && root.isBrowser(candidate) && (candidate.trackAlbum ?? "") === "")
      return false;
    return true;
  }

  // Spotify outranks everything whether it is playing or paused; among the
  // rest, a playing player beats an idle one.  Assignable, so the bar can pin
  // a specific player instead.
  property MprisPlayer player: {
    const players = Mpris.players.values;
    let best = null;
    let bestRank = -1;
    for (let i = 0; i < players.length; ++i) {
      const candidate = players[i];
      if (!root.isEligible(candidate))
        continue;

      const rank = (root.isSpotify(candidate) ? 10 : 0) + (candidate.isPlaying ? 1 : 0);
      if (rank > bestRank) {
        bestRank = rank;
        best = candidate;
      }
    }
    return best;
  }

  readonly property bool playing: root.player?.isPlaying ?? false
  readonly property string artUrl: root.player?.trackArtUrl ?? ""

  visible: root.player !== null

  // The pill paints its own background, so suppress the block hover fill.
  hoveredBgColor: "transparent"
  // Raise the pill above the block's MouseArea so the transport buttons are
  // clickable; the block MouseArea still covers everything else.
  contentZ: 1

  onClicked: function() {
    if (root.player?.canTogglePlaying)
      root.player.togglePlaying();
  }

  // cava is only worth running while a visible block is showing a playing
  // track, so the shared process is reference counted per bar instance.
  readonly property bool wantsSpectrum: root.visible && root.playing

  onWantsSpectrumChanged: {
    if (root.wantsSpectrum)
      AudioLevels.acquire();
    else
      AudioLevels.release();
  }

  Component.onDestruction: {
    if (root.wantsSpectrum)
      AudioLevels.release();
  }

  content: ClippingRectangle {
    id: pill

    implicitWidth: layout.implicitWidth + 14
    // Full bar height; BarBlock pins the block at 30.
    implicitHeight: root.height
    radius: width / 100
    color: "#26ffffff"

    // Keeps the widget legible as a unit against bright or busy album art.
    // ClippingRectangle draws the border inside its bounds and insets its
    // content by the same amount, so the outline costs the bar nothing.
    border.width: 1
    border.color: "#59FFFFFF"

    Image {
      id: art
      anchors.fill: parent
      visible: false
      source: root.artUrl
      asynchronous: true
      sourceSize.width: 64
      sourceSize.height: 64
    }

    // Blur, desaturation and darkening in a single GPU pass.
    MultiEffect {
      anchors.fill: art
      source: art
      visible: art.status === Image.Ready
      blurEnabled: true
      blurMax: 32
      blur: 1.0
      saturation: -0.3
      brightness: -0.35
    }

    // Guarantees text contrast even when there is no album art to darken.
    Rectangle {
      anchors.fill: parent
      color: "#4D000000"
    }

    RowLayout {
      id: layout
      anchors.fill: parent
      anchors.leftMargin: 4
      anchors.rightMargin: 6
      spacing: 6

      Item {
        id: disc
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignVCenter
        Accessible.ignored: true

        // Averaging the two lowest bands keeps the beat from twitching on
        // single-frame spikes.  Scale never touches the layout.
        readonly property real bass: ((AudioLevels.levels[0] ?? 0) + (AudioLevels.levels[1] ?? 0)) / 2

        scale: 1 + 0.13 * disc.bass

        // A spring rather than an eased tween: the disc overshoots slightly and
        // settles, so a kick reads as a bounce instead of a fade.
        Behavior on scale {
          SpringAnimation {
            spring: 4.0
            damping: 0.22
            mass: 0.7
            epsilon: 0.002
          }
        }

        RotationAnimation on rotation {
          id: spin
          from: 0
          to: 360
          duration: 20500
          loops: Animation.Infinite
          running: root.visible
        }

        // `paused` may only be written while the animation is running, so it is
        // applied through a guarded Binding rather than a plain binding.
        Binding {
          target: spin
          property: "paused"
          value: !root.playing
          when: spin.running
          restoreMode: Binding.RestoreNone
        }

        // The record is the album art itself, so it stays a clipped Image
        // rather than a glyph.
        ClippingRectangle {
          anchors.fill: parent
          radius: width / 2
          color: "#1C1C1E"

          Image {
            anchors.fill: parent
            source: root.artUrl
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 48
            sourceSize.height: 48
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: "#40FFFFFF"
        }

        // Spindle hole.
        Rectangle {
          anchors.centerIn: parent
          width: 5
          height: 5
          radius: width / 2
          color: "#CC000000"
          border.width: 1
          border.color: "#33FFFFFF"
        }
      }

      // Fixed width: the block must not resize as tracks change, so long
      // titles scroll instead of stretching the bar.
      ColumnLayout {
        Layout.preferredWidth: 70
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        MarqueeText {
          Layout.fillWidth: true
          text: root.player?.trackTitle || root.player?.identity || ""
          color: "white"
          pointSize: 9
          frozen: !root.playing
        }

        MarqueeText {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.player?.trackArtist ?? ""
          color: "#B3FFFFFF"
          pointSize: 7
          frozen: !root.playing
        }
      }

      MusicButton {
        Layout.alignment: Qt.AlignVCenter
        glyph: ""
        label: "Previous track"
        active: root.player?.canGoPrevious ?? false
        onActivated: root.player.previous()
      }

      MusicButton {
        Layout.alignment: Qt.AlignVCenter
        glyph: root.playing ? "" : ""
        label: root.playing ? "Pause" : "Play"
        active: root.player?.canTogglePlaying ?? false
        onActivated: root.player.togglePlaying()
      }

      MusicButton {
        Layout.alignment: Qt.AlignVCenter
        glyph: ""
        label: "Next track"
        active: root.player?.canGoNext ?? false
        onActivated: root.player.next()
      }
    }
  }
}
