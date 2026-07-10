pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool isOpen: false

    IpcHandler {
        target: "power"

        function open() { root.isOpen = true; }
        function close() { root.isOpen = false; }
        function toggle() { root.isOpen = !root.isOpen; }
    }

    LazyLoader {
        active: root.isOpen
        Overlay {
            controller: root
        }
    }

    function init() {
    }
}
