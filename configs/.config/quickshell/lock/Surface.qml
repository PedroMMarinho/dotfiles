pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

WlSessionLockSurface {
    id: surface
    color: "#1a1a1a"

    Column {
        anchors.centerIn: parent
        spacing: 16

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Controller.statusText
            color: Controller.failed ? "#ff6b6b" : "#ffffff"
            font.pixelSize: 18
        }

        Rectangle {
            width: 260
            height: 44
            radius: 22
            color: "#33ffffff"
            border.color: "#66ffffff"

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: "#ffffff"
                clip: true
                enabled: !Controller.authenticating
                onAccepted: Controller.submit(text)
            }
        }
    }

    // Grab keyboard focus when this surface appears.
    Component.onCompleted: pw.forceActiveFocus()

    // Clear + refocus + reset on a failed attempt.
    Connections {
        target: Controller
        function onFailedPulse() {
            pw.text = "";
            pw.forceActiveFocus();
        }
    }
}
