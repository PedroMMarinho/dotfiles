pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/" // for Theme singleton

PanelWindow {
    id: root

    required property var controller

    // Five actions, left -> right. mnemonic = direct-activate key.
    readonly property var actions: [
        { label: "Lock",     glyph: "", mnemonic: "l", command: ["loginctl", "lock-session"] },
        { label: "Logout",   glyph: "", mnemonic: "e", command: ["hyprctl", "dispatch", "exit"] },
        { label: "Suspend",  glyph: "", mnemonic: "s", command: ["systemctl", "suspend"] },
        { label: "Reboot",   glyph: "", mnemonic: "r", command: ["systemctl", "reboot"] },
        { label: "Shutdown", glyph: "", mnemonic: "p", command: ["systemctl", "poweroff"] }
    ]

    property int selected: 0

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "#35000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "shell:power"

    function activate(index) {
        const action = root.actions[index];
        Quickshell.execDetached({ command: action.command });
        root.controller.isOpen = false;
    }

    // Click on the dim backdrop (outside buttons) closes the menu.
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
                root.selected = (root.selected - 1 + root.actions.length) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.selected = (root.selected + 1) % root.actions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activate(root.selected);
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
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

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 20

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: button
                    required property int index
                    required property var modelData

                    readonly property bool active: root.selected === index

                    width: 110
                    height: 110
                    radius: 12
                    color: active ? Theme.get.wlogoutButtonBgHover : Theme.get.wlogoutButtonBg
                    border.width: 2
                    border.color: active ? Theme.get.wlogoutSelectedBorder : Theme.get.wlogoutBorderColor

                    HoverHandler {
                        id: hover
                        onHoveredChanged: if (hovered) root.selected = button.index
                    }

                    TapHandler {
                        onTapped: root.activate(button.index)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: button.modelData.glyph
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 36
                            color: button.active ? Theme.get.wlogoutIconSelected : Theme.get.wlogoutIconColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: button.modelData.label
                            font.pixelSize: 14
                            color: Theme.get.wlogoutLabelColor
                        }
                    }
                }
            }
        }
    }
}
