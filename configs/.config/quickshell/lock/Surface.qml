pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/" // for the Theme singleton

WlSessionLockSurface {
    id: surface
    color: "#000000"

    // --- Tunables ------------------------------------------------------
    property string displayName: Quickshell.env("USER")
    // -------------------------------------------------------------------

    // Live desktop wallpaper for this monitor (from awww via the Controller),
    // falling back to any known wallpaper if this output isn't matched.
    readonly property string wallpaperPath: {
        const m = Controller.wallpapers;
        const n = surface.screen ? surface.screen.name : "";
        if (n && m[n] !== undefined)
            return m[n];
        for (const k in m)
            return m[k];
        return "";
    }

    // WhiteSur (icon-theme) symbolic icons for the status tray.
    function batteryIcon(): string {
        const p = Controller.batteryPercent;
        if (p < 0)
            return "battery-missing-symbolic";
        const lvl = Math.max(0, Math.min(100, Math.round(p / 10) * 10));
        const charging = Controller.batteryStatus === "Charging";
        // WhiteSur has no "battery-level-100-charging-symbolic"; the full+charging
        // state is named "-charged-" instead. Using the wrong name yields a junk
        // fallback icon, so special-case it.
        if (charging)
            return lvl >= 100 ? "battery-level-100-charged-symbolic"
                              : "battery-level-" + lvl + "-charging-symbolic";
        return "battery-level-" + lvl + "-symbolic";
    }

    function wifiIcon(): string {
        const s = Controller.wifiSignal;
        if (s < 0) return "network-wireless-offline-symbolic";
        if (s >= 80) return "network-wireless-signal-excellent-symbolic";
        if (s >= 55) return "network-wireless-signal-good-symbolic";
        if (s >= 30) return "network-wireless-signal-ok-symbolic";
        if (s >= 5)  return "network-wireless-signal-weak-symbolic";
        return "network-wireless-signal-none-symbolic";
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // macOS-style gradient fallback (shown until/if a wallpaper is available).
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0d1b3a" }
            GradientStop { position: 0.55; color: "#1b1436" }
            GradientStop { position: 1.0; color: "#2a123f" }
        }
    }

    // Sharp desktop wallpaper (matches the macOS lock look).
    Image {
        id: wallpaper
        anchors.fill: parent
        source: surface.wallpaperPath ? "file://" + surface.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        // Reuse the pixmap the Controller primed, and load synchronously so the
        // surface's very first frame already has it (Controller only engages the
        // lock once this is cached, so the decode is instant — no black flash).
        cache: true
        asynchronous: false
        visible: status === Image.Ready
    }

    // Top scrim — legibility for the clock/date.
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height * 0.42
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#73000000" }
            GradientStop { position: 1.0; color: "#00000000" }
        }
    }

    // Bottom scrim — legibility for the avatar/name/field.
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: parent.height * 0.42
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#8c000000" }
        }
    }

    // --- Top-right status tray (glass) --------------------------------
    GlassPanel {
        id: tray
        wallpaperItem: wallpaper
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.round(surface.height * 0.022)
        anchors.rightMargin: Math.round(surface.width * 0.018)
        height: Math.round(surface.height * 0.044)
        width: trayRow.width + height * 1.0
        glassRadius: height / 2
        tint: Theme.get.lockTrayTint
        glassBorder: Theme.get.lockTrayBorder

        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: tray.height * 0.72 // gap between tray groups

            // Keyboard: layout label + icon, tightly grouped and clickable to
            // cycle layouts (MOD+SPACE can't reach us behind the session lock).
            MouseArea {
                id: kbGroup
                anchors.verticalCenter: parent.verticalCenter
                width: kbRow.width
                height: kbRow.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                opacity: containsMouse ? 0.65 : 1.0
                onClicked: Controller.cycleKeyboard()

                Behavior on opacity { NumberAnimation { duration: 100 } }

                Row {
                    id: kbRow
                    anchors.centerIn: parent
                    spacing: tray.height * 0.26

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Controller.keyboardLayout
                        color: Theme.get.lockText
                        font.family: "SF Pro Text"
                        font.weight: Font.Medium
                        font.pixelSize: tray.height * 0.46
                    }

                    TrayIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "on-screen-keyboard-symbolic"
                        size: tray.height * 0.62
                    }
                }
            }

            TrayIcon {
                anchors.verticalCenter: parent.verticalCenter
                iconName: surface.batteryIcon()
                visible: Controller.batteryPercent >= 0
                size: tray.height * 0.62
            }

            TrayIcon {
                anchors.verticalCenter: parent.verticalCenter
                iconName: surface.wifiIcon()
                opacity: Controller.wifiSignal >= 0 ? 1.0 : 0.5
                size: tray.height * 0.62
            }
        }
    }

    // --- Clock + date, upper third (date above the clock) -------------
    Text {
        id: dateText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.13
        text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
        color: Theme.get.lockText
        font.family: "SF Pro Display"
        font.weight: Font.Bold
        font.pixelSize: Math.round(surface.height * 0.028)
    }

    // Clock, upper third.
    Text {
        id: clockText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dateText.bottom
        anchors.topMargin: Math.round(-surface.height * 0.01)
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.get.lockText
        font.family: "SF Pro Display"
        font.weight: Font.DemiBold
        font.pixelSize: Math.round(surface.height * 0.115)
    }

    // --- Avatar + name + password field, lower-center -----------------

    // Frosted-glass password field (shakes on failure). Anchored directly to
    // the surface so GlassPanel's x/y map cleanly onto the blur layer.
    GlassPanel {
        id: pill
        wallpaperItem: wallpaper
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.11
        width: Math.round(surface.width * 0.145)
        height: Math.round(surface.height * 0.04)
        glassRadius: height / 2
        tint: Controller.failed ? Theme.get.lockGlassTintError : Theme.get.lockGlassTint
        glassBorder: Controller.failed ? Theme.get.lockGlassBorderError : Theme.get.lockGlassBorder

        Behavior on tint { ColorAnimation { duration: 150 } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: pill.height * 0.7
            anchors.verticalCenter: parent.verticalCenter
            visible: pw.text.length === 0
            text: Controller.statusText
            color: Controller.failed ? Theme.get.lockTextError : Theme.get.lockTextDim
            font.family: "SF Pro Text"
            font.pixelSize: pill.height * 0.36
        }

        TextInput {
            id: pw
            anchors.fill: parent
            anchors.leftMargin: pill.height * 0.7
            anchors.rightMargin: pill.height * 1.4
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: Theme.get.lockText
            clip: true
            font.family: "SF Pro Text"
            font.pixelSize: pill.height * 0.4
            enabled: !Controller.authenticating
            onAccepted: Controller.submit(text)

            // Mirror this field into the shared buffer so every monitor's field
            // stays in sync. _applying guards against the echo when we're the
            // one being written from the buffer (below), avoiding a loop.
            property bool _applying: false
            onTextChanged: {
                if (!_applying)
                    Controller.passwordDraft = text;
            }
            Connections {
                target: Controller
                function onPasswordDraftChanged() {
                    if (pw.text === Controller.passwordDraft)
                        return;
                    pw._applying = true;
                    pw.text = Controller.passwordDraft;
                    pw._applying = false;
                }
            }
        }

        // Arrow-in-circle submit affordance (macOS style).
        Rectangle {
            id: submitBtn
            anchors.right: parent.right
            anchors.rightMargin: (pill.height - height) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: pill.height * 0.72
            height: width
            radius: width / 2
            color: Theme.get.lockGlassTint
            border.color: Theme.get.lockGlassBorder
            border.width: Math.max(1, pill.height * 0.04)
            visible: pw.text.length > 0 && !Controller.authenticating

            Text {
                anchors.centerIn: parent
                text: "→" // →
                color: Theme.get.lockText
                font.pixelSize: parent.height * 0.62
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Controller.submit(pw.text)
            }
        }

        // Horizontal shake on a failed attempt.
        SequentialAnimation {
            id: shake
            loops: 1
            NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 12; duration: 40 }
            NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -12; duration: 80 }
            NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 8; duration: 60 }
            NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
        }
    }

    Text {
        id: nameText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: pill.top
        anchors.bottomMargin: parent.height * 0.018
        text: surface.displayName
        color: Theme.get.lockText
        font.family: "SF Pro Text"
        font.weight: Font.DemiBold
        font.pixelSize: Math.round(surface.height * 0.019)
    }

    // Circular avatar (properly masked) with glyph fallback.
    Rectangle {
        id: avatarRing
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: nameText.top
        anchors.bottomMargin: parent.height * 0.010
        width: Math.round(surface.height * 0.065)
        height: width
        radius: width / 2
        color: Theme.get.lockAvatarBg

        // Circular mask (sibling of the image so it can be its layer maskSource).
        Item {
            id: avatarMask
            anchors.fill: avatarImg
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "white"
            }
        }

        // Rendering the image to its own layer makes the effect sample the
        // *cropped* item (honoring PreserveAspectCrop) instead of the raw,
        // letterboxed source texture — so the portrait avatar fills the circle.
        Image {
            id: avatarImg
            anchors.fill: parent
            anchors.margins: 2
            source: "root:/lock/avatars/" + Theme.get.lockAvatar + ".png"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: avatarImg.status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: avatarMask
            }
        }

        // Fallback icon (WhiteSur avatar) when no avatar image exists.
        TrayIcon {
            anchors.centerIn: parent
            visible: avatarImg.status !== Image.Ready
            iconName: "avatar-default-symbolic"
            size: parent.height * 0.55
        }
    }

    Component.onCompleted: pw.forceActiveFocus()

    Connections {
        target: Controller
        function onFailedPulse() {
            // The buffer is cleared centrally (mirrors to every monitor); here
            // we just restore focus and shake this surface's field.
            pw.forceActiveFocus();
            shake.restart();
        }
    }
}
