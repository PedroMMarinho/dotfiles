pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/lock" as Lock

Singleton {
    id: root
    property bool isOpen: false

    // Shared selection so every monitor's overlay highlights the same button.
    property int selected: 0

    onIsOpenChanged: if (isOpen) selected = 0

    IpcHandler {
        target: "power"

        function open() { root.isOpen = true; }
        function close() { root.isOpen = false; }
        function toggle() { root.isOpen = !root.isOpen; }
    }

    LazyLoader {
        active: root.isOpen

        Scope {
            Variants {
                model: Quickshell.screens

                Overlay {
                    controller: root
                }
            }
        }
    }

    // Sleep action: engage the lock screen first so the session is already
    // locked when it wakes up, then suspend once the compositor lock is up.
    function sleepWithLock() {
        if (Lock.Controller.locked) {
            root._suspend();
            return;
        }
        Lock.Controller.lock();
        suspendFallback.restart();
    }

    function _suspend() {
        Quickshell.execDetached({ command: ["systemctl", "suspend"] });
    }

    Connections {
        target: Lock.Controller

        function onLockedChanged() {
            if (Lock.Controller.locked && suspendFallback.running) {
                suspendFallback.stop();
                root._suspend();
            }
        }
    }

    // If the lock never engages (wallpaper query stalls, etc.) suspend anyway
    // rather than leaving the click doing nothing.
    Timer {
        id: suspendFallback
        interval: 2000
        onTriggered: root._suspend()
    }

    function init() {
    }
}
