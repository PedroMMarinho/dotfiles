pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Frosted-glass text: shows a blurred slice of the wallpaper clipped to the
// glyph shapes, with a translucent white sheen on top for legibility. Like
// GlassPanel, it MUST be a direct child of the item the wallpaper fills so its
// x/y are already in the wallpaper's coordinate space.
Item {
    id: root

    property Item wallpaperItem
    property string text
    property color sheen: "#73FFFFFF" // translucent white overlay
    property real blurAmount: 0.8

    // Expose the font so callers can set font.family/pixelSize/weight.
    property alias font: maskText.font

    implicitWidth: maskText.implicitWidth
    implicitHeight: maskText.implicitHeight

    readonly property rect sampleRect: Qt.rect(x, y, width, height)

    // Hidden white text used as the alpha mask for the glyph shapes.
    Text {
        id: maskText
        text: root.text
        color: "white"
        visible: false
        layer.enabled: true
    }

    // Grab the wallpaper behind the text (off-screen; blur source only).
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

    // Blurred wallpaper clipped to the glyphs.
    MultiEffect {
        anchors.fill: parent
        source: grab
        visible: root.wallpaperItem !== null
        blurEnabled: true
        blur: root.blurAmount
        blurMax: 32
        brightness: 0.15
        maskEnabled: true
        maskSource: maskText
        maskThresholdMin: 0.4
    }

    // Translucent white sheen + crisp glyph edges (always visible, so the text
    // stays readable even if the blur layer fails to render).
    Text {
        anchors.fill: parent
        text: root.text
        font: maskText.font
        color: root.sheen
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
