pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Absolute path of the capture currently shown by the thumbnail.
    property string file: ""
    // isOpen keeps the window loaded; revealed drives the slide animation.
    // They differ only during the slide-out, so the exit animation can play
    // before the window unloads.
    property bool isOpen: false
    property bool revealed: false
    // Popup position, expressed as layer-surface margins. Dragging in
    // Thumbnail.qml writes these; every new capture resets to bottom-right.
    property int posRight: 12
    property int posBottom: 12

    IpcHandler {
        target: "screenshot"

        function show(path: string): void {
            unloadTimer.stop();
            root.file = path;
            root.posRight = 12;
            root.posBottom = 12;
            root.isOpen = true;
            root.revealed = true;
            dismissTimer.restart();
        }

        // Instant hide, no slide-out: screenshot.sh calls this right before
        // capturing so a previous thumbnail is never in the new screenshot.
        function hide(): void {
            dismissTimer.stop();
            unloadTimer.stop();
            root.revealed = false;
            root.isOpen = false;
        }
    }

    // macOS keeps the thumbnail around while the pointer is over it.
    function hold() { dismissTimer.stop(); }
    function release() { dismissTimer.restart(); }

    function dismiss() {
        dismissTimer.stop();
        root.revealed = false;
        unloadTimer.restart();
    }

    function openEditor() {
        Quickshell.execDetached({ command: ["swappy", "-f", root.file] });
        dismiss();
    }

    Timer {
        id: dismissTimer
        interval: 5000
        onTriggered: root.dismiss()
    }

    // Slightly longer than the slide-out animation in Thumbnail.qml.
    Timer {
        id: unloadTimer
        interval: 300
        onTriggered: root.isOpen = false
    }

    LazyLoader {
        active: root.isOpen

        Thumbnail {
            controller: root
        }
    }

    function init() {
    }
}
