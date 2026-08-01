pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "root:/" // for Theme singleton

// The HUD itself: a rounded square floating near the bottom of the screen,
// glyph on top, segmented level bar underneath.
PanelWindow {
    id: root

    required property var controller

    // Set by the Variants in Controller.qml -- one overlay per monitor.
    property var modelData
    screen: modelData

    // Only the focused monitor shows the HUD. Mirroring it would put three
    // copies in your peripheral vision every time you touch a volume key.
    readonly property bool focused: Hyprland.focusedMonitor == Hyprland.monitorFor(root.screen)

    // Set once the component exists so the opacity binding below is a real
    // change rather than an initial value -- Behavior does not animate the
    // latter, and the HUD would pop in instead of fading.
    property bool entered: false
    Component.onCompleted: root.entered = true

    visible: root.controller.mapped && root.focused

    readonly property int panelSize: 180

    anchors.bottom: true
    margins.bottom: Math.round((root.screen?.height ?? 1080) * 0.15)
    implicitWidth: root.panelSize
    implicitHeight: root.panelSize

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "shell:osd"

    // Purely informational: an empty input region means the HUD never takes a
    // click or a key away from whatever is underneath it.
    mask: Region {}

    Rectangle {
        id: hud
        anchors.fill: parent

        radius: 22
        color: Theme.get.wlogoutPanelBg
        border.width: 1
        border.color: Theme.get.wlogoutPanelBorder

        readonly property bool up: root.controller.shown && root.entered

        opacity: hud.up ? 1 : 0
        scale: hud.up ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: hud.up ? 120 : root.controller.fadeDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: hud.up ? 140 : root.controller.fadeDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }

        // Symbolic icons ship as currentColor, which Qt renders dark. Overlay
        // white so the glyph reads on the dark panel whatever the icon theme.
        Image {
            id: glyph
            visible: false

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.15)
            width: 84
            height: 84

            source: root.controller.icon ? Quickshell.iconPath(root.controller.icon, true) : ""
            sourceSize.width: width
            sourceSize.height: height
        }

        ColorOverlay {
            anchors.fill: glyph
            source: glyph
            color: "white"
            opacity: root.controller.muted ? 0.5 : 1

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        // Classic macOS segmented level bar. 16 segments at 5% volume steps
        // means one key press always moves at least one segment.
        Row {
            id: segments

            readonly property int count: 16
            readonly property int filled: root.controller.muted
                ? 0
                : Math.round(root.controller.level * segments.count)

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.73)
            spacing: 4

            Repeater {
                model: segments.count

                Rectangle {
                    required property int index

                    width: 6
                    height: 14
                    radius: 1.5
                    color: "white"
                    opacity: index < segments.filled ? 0.95 : 0.2

                    Behavior on opacity {
                        NumberAnimation { duration: 90 }
                    }
                }
            }
        }
    }
}
