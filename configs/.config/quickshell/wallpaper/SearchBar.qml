import QtQuick
import QtQuick.Controls.Basic

FrostedPanel {
    id: root

    property alias query: field.text
    // Keys typed here are offered to this item first (gallery navigation).
    property Item keyTarget
    signal dismissed()

    cornerRadius: height / 2

    function focusSearch() {
        field.forceActiveFocus()
    }

    Item {
        id: glyph
        width: 14
        height: 14
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: 10
            height: 10
            radius: 5
            color: "transparent"
            border.width: 1.6
            border.color: Qt.rgba(1, 1, 1, 0.65)
        }
        Rectangle {
            x: 9
            y: 10
            width: 6
            height: 1.6
            radius: 0.8
            rotation: 45
            transformOrigin: Item.Left
            color: Qt.rgba(1, 1, 1, 0.65)
        }
    }

    TextField {
        id: field
        anchors.left: glyph.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        background: null
        color: "white"
        selectionColor: "#0A84FF"
        font.pixelSize: 14
        placeholderText: qsTr("Search Wallpapers")
        placeholderTextColor: Qt.rgba(1, 1, 1, 0.5)

        Keys.forwardTo: root.keyTarget ? [root.keyTarget] : []
        Keys.onEscapePressed: {
            if (text)
                text = ""
            else
                root.dismissed()
        }
    }
}
