import QtQuick
import QtQuick.Effects

// Floating macOS-style material panel: rounded rect with tint, hairline
// border and soft drop shadow. When backgroundItem is set, it additionally
// blurs whatever that item shows behind the panel (frosted glass).
Item {
    id: root

    property Item backgroundItem: null
    property real cornerRadius: 22
    property color tint: Qt.rgba(0.09, 0.09, 0.11, 0.42)
    property bool showShadow: true

    RectangularShadow {
        anchors.fill: parent
        visible: root.showShadow
        radius: root.cornerRadius
        blur: 36
        offset.y: 8
        cached: true
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    ShaderEffectSource {
        id: backdrop
        anchors.fill: parent
        visible: false
        sourceItem: root.backgroundItem
        sourceRect: {
            if (!root.backgroundItem)
                return Qt.rect(0, 0, 0, 0)
            root.x; root.y; root.width; root.height
            const pos = root.mapToItem(root.backgroundItem, 0, 0)
            return Qt.rect(pos.x, pos.y, root.width, root.height)
        }
    }

    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: root.cornerRadius
        visible: false
    }

    ShaderEffectSource {
        id: maskTexture
        anchors.fill: parent
        visible: false
        sourceItem: maskShape
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.backgroundItem !== null
        source: backdrop
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.15
        maskEnabled: true
        maskSource: maskTexture
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.tint
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }
}
