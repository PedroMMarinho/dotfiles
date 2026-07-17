pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var controller

    screen: {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s;
        }
        return Quickshell.screens[0];
    }

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "#30000000"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "shell:wallpaper"

    // Click outside the panel dismisses the picker.
    MouseArea {
        anchors.fill: parent
        onClicked: root.controller.isOpen = false
    }

    FrostedPanel {
        id: panel
        width: Math.min(920, parent.width - 80)
        height: 212
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 130
        cornerRadius: 26
        tint: Qt.rgba(0.1, 0.1, 0.13, 0.92)
        scale: 0.96
        opacity: 0

        // NumberAnimation, not Animators: this starts during component
        // creation, before the window's scene graph exists, where
        // render-thread Animators silently never apply.
        ParallelAnimation {
            running: true
            NumberAnimation { target: panel; property: "scale"; from: 0.96; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }

        // Swallow clicks so they don't reach the dismiss area behind.
        MouseArea {
            anchors.fill: parent
        }

        SearchBar {
            id: searchBar
            width: 340
            height: 40
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            showShadow: false
            tint: Qt.rgba(1, 1, 1, 0.07)
            keyTarget: gallery.listItem
            onQueryChanged: root.controller.query = query
            onDismissed: root.controller.isOpen = false
        }

        WallpaperGallery {
            id: gallery
            anchors.top: searchBar.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: 126
            model: root.controller.visibleEntries
            appliedPath: root.controller.currentPath
            onConfirmed: (path, isVideo) => root.controller.apply(path, isVideo)
        }
    }

    Connections {
        target: root.controller

        function onModelRebuilt() {
            gallery.currentIndex = 0;
            gallery.listItem.positionViewAtBeginning();
        }
    }

    Component.onCompleted: searchBar.focusSearch()
}
