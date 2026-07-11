pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    // Drives the compositor-enforced session lock.
    property bool locked: false

    IpcHandler {
        target: "lock"

        function lock(): void { root.locked = true; }
        function unlock(): void { root.locked = false; } // debug escape hatch; removed in Task 3
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        // WlSessionLock's default property is `surface`; this template is
        // instantiated once per connected monitor by the compositor.
        Surface {}
    }

    function init() {}
}
