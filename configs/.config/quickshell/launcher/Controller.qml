pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool isOpen: false

    HistoryManager {
        id: history
    }

    property alias historyManager: history

    IpcHandler {
        target: "launcher"

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