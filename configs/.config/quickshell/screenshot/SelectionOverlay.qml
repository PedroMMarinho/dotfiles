pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Freeze-first selection overlay: one window per monitor. While mapped it
// blanks the system cursor — no pointer, hardware or software, gets
// composited into grim's frame. Once controller.frozen flips, it displays
// this monitor's slice of the frozen master and the mode's selection UI.
Scope {
    id: root

    required property var controller

    readonly property var origin: controller.layoutOrigin()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay

            required property var modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell:screenshot-overlay"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Frozen frame slice for this monitor. Never shown in full mode —
            // full captures straight to the target file with no UI.
            Image {
                anchors.fill: parent
                visible: root.controller.frozen && root.controller.mode !== "full"
                source: root.controller.frozen ? "file://" + root.controller.masterPath : ""
                sourceClipRect: Qt.rect(
                    overlay.modelData.x - root.origin.x,
                    overlay.modelData.y - root.origin.y,
                    overlay.width, overlay.height)
                cache: false
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.BlankCursor
                focus: true

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        root.controller.cancelSession();
                }

                Keys.onEscapePressed: root.controller.cancelSession()
            }
        }
    }
}
