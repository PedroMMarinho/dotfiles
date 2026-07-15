pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var controller

    // Fixed width like macOS; height follows the capture's aspect ratio.
    readonly property int thumbWidth: 220
    readonly property int shadowPad: 24

    anchors {
        right: true
        bottom: true
    }
    // Position comes from the controller so dragging survives image swaps
    // and show() can reset it to the corner.
    margins {
        right: root.controller.posRight
        bottom: root.controller.posBottom
    }

    implicitWidth: thumbWidth + shadowPad * 2
    implicitHeight: frame.height + shadowPad * 2

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:screenshot"

    Item {
        id: slide

        width: parent.width
        height: parent.height
        // Slide in from beyond the right edge, macOS style.
        x: root.controller.revealed ? 0 : root.implicitWidth + 16

        Behavior on x {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: frame

            x: root.shadowPad
            y: root.shadowPad
            width: root.thumbWidth
            height: img.status === Image.Ready && img.sourceSize.width > 0
                ? Math.min(Math.round(width * img.sourceSize.height / img.sourceSize.width), 220) + 8
                : 130
            radius: 10
            color: "#F22A2A2A"          // macOS dark charcoal frame
            border.color: "#40FFFFFF"   // subtle light hairline
            border.width: 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#80000000"
                shadowBlur: 0.9
                shadowVerticalOffset: 4
            }

            Image {
                id: img

                anchors.fill: parent
                anchors.margins: 4
                source: root.controller.file !== "" ? "file://" + root.controller.file : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mask
                }
            }

            Item {
                id: mask

                anchors.fill: img
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "black"
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                // Press-and-move beyond the threshold drags the popup by
                // adjusting the layer margins (Hyprland never moves the
                // surface itself, so there is nothing to jitter). A release
                // below the threshold is a click and opens the editor.
                property real pressX: 0
                property real pressY: 0
                property bool dragging: false

                onEntered: root.controller.hold()
                onExited: root.controller.release()

                onPressed: (event) => {
                    pressX = event.x;
                    pressY = event.y;
                    dragging = false;
                    root.controller.hold();
                }

                onPositionChanged: (event) => {
                    if (!pressed)
                        return;
                    const dx = event.x - pressX;
                    const dy = event.y - pressY;
                    if (!dragging && Math.abs(dx) < 6 && Math.abs(dy) < 6)
                        return;
                    dragging = true;
                    const maxRight = root.screen.width - root.implicitWidth;
                    const maxBottom = root.screen.height - root.implicitHeight;
                    root.controller.posRight = Math.max(0, Math.min(root.controller.posRight - dx, maxRight));
                    root.controller.posBottom = Math.max(0, Math.min(root.controller.posBottom - dy, maxBottom));
                }

                onReleased: {
                    if (!dragging)
                        root.controller.openEditor();
                    else if (!containsMouse)
                        root.controller.release();
                }
            }
        }
    }
}
