pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

WlSessionLockSurface {
    id: surface
    color: "#1a1a1a"

    Text {
        anchors.centerIn: parent
        text: "Locked (Task 1 test surface)"
        color: "#ffffff"
        font.pixelSize: 24
    }
}
