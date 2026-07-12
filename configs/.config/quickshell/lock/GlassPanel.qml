pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Frosted-glass panel with real macOS-style backdrop blur. It grabs the region
// of the (sharp, visible) wallpaper directly behind itself, blurs that copy,
// and masks it to a rounded shape. MUST be a direct child of the same item the
// wallpaper fills (the lock surface) so this panel's x/y are already in the
// wallpaper's coordinate space — no mapToItem, and it stays reactive to layout.
Item {
    id: root

    // The sharp, visible wallpaper Image to sample behind this panel.
    property Item wallpaperItem
    property real glassRadius: height / 2
    property color tint: "#2EFFFFFF"
    property color glassBorder: "#59FFFFFF"
    property real glassBorderWidth: 1
    property real blurAmount: 1.0

    // Caller children render ABOVE the glass, so input keeps working even if
    // the blur layer fails to render for any reason.
    default property alias content: contentHolder.data

    readonly property rect sampleRect: Qt.rect(x, y, width, height)

    // Grab the wallpaper pixels behind this panel (kept off-screen; used only
    // as a texture for the blur below).
    ShaderEffectSource {
        id: grab
        anchors.fill: parent
        sourceItem: root.wallpaperItem
        sourceRect: root.sampleRect
        live: true
        recursive: false
        hideSource: false
        visible: false
    }

    // Blur that grabbed region and round it (one MultiEffect does both).
    MultiEffect {
        anchors.fill: parent
        source: grab
        visible: root.wallpaperItem !== null
        blurEnabled: true
        blur: root.blurAmount
        blurMax: 48
        brightness: -0.03
        maskEnabled: true
        maskSource: glassMask
        maskThresholdMin: 0.5
    }

    Item {
        id: glassMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: root.glassRadius
            color: "white"
        }
    }

    // Frost tint (rounded natively by the Rectangle).
    Rectangle {
        anchors.fill: parent
        radius: root.glassRadius
        color: root.tint
    }

    // Hairline border.
    Rectangle {
        anchors.fill: parent
        radius: root.glassRadius
        color: "transparent"
        border.color: root.glassBorder
        border.width: root.glassBorderWidth
    }

    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
