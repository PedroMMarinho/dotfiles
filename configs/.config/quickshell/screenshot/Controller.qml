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

    IpcHandler {
        target: "screenshot"

        function show(path: string): void {
            unloadTimer.stop();
            root.file = path;
            root.isOpen = true;
            root.revealed = true;
            dismissTimer.restart();
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
