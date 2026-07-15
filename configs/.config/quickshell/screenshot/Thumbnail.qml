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
    margins {
        right: 12
        bottom: 12
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

                onEntered: root.controller.hold()
                onExited: {
                    if (!pressed)
                        root.controller.release();
                }
                onClicked: root.controller.openEditor()
            }
        }
    }
}
