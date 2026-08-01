pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// macOS-style on-screen display for volume, microphone and brightness.
//
// Observation-only by design: the multimedia keybinds still run wpctl and
// brightnessctl exactly as before and this notices the result. So the HUD also
// appears for changes made from pavucontrol, the Sound bar block's scroll
// wheel, or an app's own mixer -- which is what macOS does -- and nothing about
// the keys depends on the shell being alive.
//
// All state lives here rather than in Overlay because Overlay is instantiated
// once per monitor; a view-owned timer would run three times over.
Singleton {
    id: root

    // How long the HUD stays up after the last change, and how long the
    // surface lingers past that so the fade-out has time to finish.
    readonly property int holdDuration: 1500
    readonly property int fadeDuration: 250

    property string kind: ""   // "volume" | "mic" | "brightness"
    property real level: 0     // 0..1, already clamped for display
    property bool muted: false
    property string icon: ""

    // shown drives the fade; mapped keeps the layer surface alive across it.
    property bool shown: false
    property bool mapped: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property var sinkAudio: root.sink?.audio ?? null
    readonly property var sourceAudio: root.source?.audio ?? null

    // Nothing is presented until the shell has settled. Pipewire populates node
    // properties asynchronously after the tracker binds, and those first values
    // landing would otherwise flash a HUD at every reload. Note this cannot be
    // "swallow the first signal per device": a source that is never touched
    // emits nothing to swallow, so the swallow would land on your first real
    // key press instead of on startup.
    property bool settled: false

    Timer {
        interval: 1500
        running: true
        onTriggered: root.settled = true
    }

    // Last observed values, so a signal that carries no actual change (or a
    // default-device swap to a device at the same level) does not pop the HUD.
    property real lastSinkVolume: -1
    property var lastSinkMuted: null
    property real lastSourceVolume: -1
    property var lastSourceMuted: null
    property real lastBrightness: -1

    onShownChanged: {
        if (root.shown) {
            unmap.stop();
            root.mapped = true;
        } else {
            unmap.restart();
        }
    }

    function present(kind, level, muted, icon) {
        root.kind = kind;
        // The volume keybind allows overamplification to 120%; the bar stays
        // full rather than growing past the panel, as macOS does.
        root.level = Math.max(0, Math.min(1, level));
        root.muted = muted;
        root.icon = icon;
        root.shown = true;
        hold.restart();
    }

    Timer {
        id: hold
        interval: root.holdDuration
        onTriggered: root.shown = false
    }

    Timer {
        id: unmap
        interval: root.fadeDuration + 50
        onTriggered: root.mapped = false
    }

    // Same thresholds as bar/blocks/Sound.qml, so the HUD glyph and the bar
    // glyph never disagree.
    function volumeIcon(vol, muted) {
        if (muted || vol <= 0)
            return "audio-volume-muted-symbolic";
        if (vol < 0.33)
            return "audio-volume-low-symbolic";
        if (vol < 0.66)
            return "audio-volume-medium-symbolic";
        if (vol < 1.0)
            return "audio-volume-high-symbolic";
        return "audio-volume-overamplified-symbolic";
    }

    function micIcon(vol, muted) {
        if (muted || vol <= 0)
            return "microphone-sensitivity-muted-symbolic";
        if (vol < 0.33)
            return "microphone-sensitivity-low-symbolic";
        if (vol < 0.66)
            return "microphone-sensitivity-medium-symbolic";
        return "microphone-sensitivity-high-symbolic";
    }

    function brightnessIcon(value) {
        return value < 0.5 ? "display-brightness-low-symbolic"
                           : "display-brightness-high-symbolic";
    }

    function reportSink() {
        const audio = root.sinkAudio;
        if (!audio)
            return;

        const changed = audio.volume !== root.lastSinkVolume
                     || audio.muted !== root.lastSinkMuted;
        root.lastSinkVolume = audio.volume;
        root.lastSinkMuted = audio.muted;

        if (!root.settled || !changed)
            return;

        root.present("volume", audio.volume, audio.muted,
                     root.volumeIcon(audio.volume, audio.muted));
    }

    function reportSource() {
        const audio = root.sourceAudio;
        if (!audio)
            return;

        const changed = audio.volume !== root.lastSourceVolume
                     || audio.muted !== root.lastSourceMuted;
        root.lastSourceVolume = audio.volume;
        root.lastSourceMuted = audio.muted;

        if (!root.settled || !changed)
            return;

        root.present("mic", audio.volume, audio.muted,
                     root.micIcon(audio.volume, audio.muted));
    }

    // Record the level the moment a device binds, so the first key press is a
    // real change to compare against rather than the value being seeded.
    onSinkAudioChanged: root.reportSink()
    onSourceAudioChanged: root.reportSource()

    // Pipewire node properties only stay bound while the node is tracked.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Connections {
        target: root.sinkAudio
        ignoreUnknownSignals: true

        function onVolumeChanged() { root.reportSink(); }
        function onMutedChanged() { root.reportSink(); }
    }

    Connections {
        target: root.sourceAudio
        ignoreUnknownSignals: true

        function onVolumeChanged() { root.reportSource(); }
        function onMutedChanged() { root.reportSource(); }
    }

    Connections {
        target: Backlight

        function onValueChanged() {
            if (Backlight.value < 0)
                return;

            const changed = Backlight.value !== root.lastBrightness;
            root.lastBrightness = Backlight.value;

            if (!root.settled || !changed)
                return;

            root.present("brightness", Backlight.value, false,
                         root.brightnessIcon(Backlight.value));
        }
    }

    // One overlay per monitor; each decides for itself whether it is the
    // focused one. Loaded only while the HUD is up.
    LazyLoader {
        active: root.mapped

        Scope {
            Variants {
                model: Quickshell.screens

                Overlay {
                    controller: root
                }
            }
        }
    }

    function init() {
    }
}
