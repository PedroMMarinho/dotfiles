pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/" // for Theme singleton

PanelWindow {
    id: root

    required property var controller

    // Set by the Variants in Controller.qml — one overlay per monitor.
    property var modelData
    screen: modelData

    // Five actions, left -> right (ordered to match the reference image).
    // mnemonic = direct-activate key; number keys 1-5 map by position.
    // "sleep: true" routes through the controller so the lock screen engages
    // before suspending. The logout dispatcher must use the Lua-mode spelling
    // ("hl.dsp.exit()") — plain "exit" is rejected under a Lua Hyprland config.
    readonly property var actions: [
        { label: "Shutdown", icon: "root:/power/icons/power.svg",     mnemonic: "p", command: ["systemctl", "poweroff"] },
        { label: "Reboot",   icon: "root:/power/icons/rotate-cw.svg", mnemonic: "r", command: ["systemctl", "reboot"] },
        { label: "Sleep",    icon: "root:/power/icons/moon.svg",      mnemonic: "s", sleep: true },
        { label: "Logout",   icon: "root:/power/icons/log-out.svg",   mnemonic: "e", command: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"] },
        //{ label: "Lock",     icon: "root:/power/icons/lock.svg",      mnemonic: "l", command: ["loginctl", "lock-session"] }
    ]

    // Selection lives on the controller so all monitors mirror it.
    readonly property int selected: controller.selected

    // The overlay is anchored to all screen edges, so width/height == the monitor
    // size. Derive one base "cell" (button) size from the smaller dimension and
    // scale everything off it, so the menu grows/shrinks with the monitor.
    // Tune the 0.13 factor to make the whole menu bigger or smaller.
    readonly property int cell: Math.round(Math.min(width, height) * 0.13)
    readonly property int gap: Math.round(cell * 0.18)
    readonly property int pad: Math.round(cell * 0.30)
    readonly property int iconSize: Math.round(cell * 0.42)
    readonly property int labelSize: Math.round(cell * 0.15)

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "#66000000" // darkened backdrop so focus stays on the panel
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "shell:power"

    function activate(index) {
        const action = root.actions[index];
        root.controller.isOpen = false;
        if (action.sleep)
            root.controller.sleepWithLock();
        else
            Quickshell.execDetached({ command: action.command });
    }

    // Click on the dim backdrop (outside the panel) closes the menu. The panel itself
    // absorbs clicks (via its own MouseArea) so clicking the frosted glass does nothing.
    MouseArea {
        anchors.fill: parent
        onClicked: root.controller.isOpen = false
    }

    // Keyboard handling lives on a focused item covering the window.
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.controller.isOpen = false

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left) {
                root.controller.selected = (root.selected - 1 + root.actions.length) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.controller.selected = (root.selected + 1) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate(root.selected);
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_1 + root.actions.length - 1) {
                root.activate(event.key - Qt.Key_1);
                event.accepted = true;
            } else if (event.text.length === 1) {
                for (let i = 0; i < root.actions.length; i++) {
                    if (root.actions[i].mnemonic === event.text.toLowerCase()) {
                        root.activate(i);
                        event.accepted = true;
                        break;
                    }
                }
            }
        }

        // Frosted macOS-style container holding the action row.
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: buttonRow.width + root.pad * 2
            height: buttonRow.height + root.pad * 2
            radius: Math.round(root.cell * 0.20)
            color: Theme.get.wlogoutPanelBg
            border.width: 1
            border.color: Theme.get.wlogoutPanelBorder

            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "#88000000"
                shadowBlur: 1.0
                shadowVerticalOffset: 8
            }

            // Absorb clicks that land on the panel's padding/border or the gaps
            // between buttons, so they don't fall through to the backdrop and close
            // the menu. Buttons are declared after this, so they still receive taps.
            MouseArea {
                anchors.fill: parent
            }

            Row {
                id: buttonRow
                anchors.centerIn: parent
                spacing: root.gap

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        id: button
                        required property int index
                        required property var modelData

                        readonly property bool active: root.selected === index

                        width: root.cell
                        height: root.cell
                        radius: Math.round(root.cell * 0.15)
                        color: active ? Theme.get.wlogoutButtonBgHover : Theme.get.wlogoutButtonBg
                        border.width: active ? 2 : 1
                        border.color: active ? Theme.get.wlogoutSelectedBorder : Theme.get.wlogoutBorderColor

                        HoverHandler {
                            onHoveredChanged: if (hovered) root.controller.selected = button.index
                        }

                        TapHandler {
                            onTapped: root.activate(button.index)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: Math.round(root.cell * 0.09)

                            Image {
                                id: iconImg
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: button.modelData.icon
                                sourceSize.width: root.iconSize
                                sourceSize.height: root.iconSize
                                width: root.iconSize
                                height: root.iconSize
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    colorizationColor: button.active ? Theme.get.wlogoutIconSelected : Theme.get.wlogoutIconColor
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: button.modelData.label
                                font.pixelSize: root.labelSize
                                color: Theme.get.wlogoutLabelColor
                            }
                        }
                    }
                }
            }
        }
    }
}
