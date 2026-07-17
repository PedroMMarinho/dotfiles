import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property int index
    required property string name
    required property string path
    required property string fileUrl
    required property string thumbUrl
    required property bool isVideo
    required property bool thumbReady

    // Shared rounded-rect texture from the gallery, used to clip every thumbnail.
    property Item maskProvider
    property bool current: false
    property bool applied: false

    signal tapped()
    signal activated()

    implicitWidth: 168
    implicitHeight: 120

    Accessible.role: Accessible.Button
    Accessible.name: name

    scale: current ? 1 : 0.9
    Behavior on scale {
        ScaleAnimator { duration: 180; easing.type: Easing.OutCubic }
    }

    RectangularShadow {
        anchors.fill: thumb
        radius: 10
        blur: 14
        offset.y: 3
        cached: true
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    Rectangle {
        anchors.fill: thumb
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.1)
        visible: !root.thumbReady
    }

    Image {
        id: thumb
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: 168
        height: 90
        // Cached thumbnail once generated; images fall back to the original
        // file so a cold cache still shows something.
        source: root.thumbReady ? root.thumbUrl : (root.isVideo ? "" : root.fileUrl)
        sourceSize: Qt.size(336, 180)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: root.maskProvider
        }
    }

    Rectangle {
        anchors.fill: thumb
        anchors.margins: -3
        radius: 13
        color: "transparent"
        border.width: 3
        border.color: "#0A84FF"
        opacity: root.current ? 1 : 0
        Behavior on opacity {
            OpacityAnimator { duration: 160 }
        }
    }

    Rectangle {
        anchors.top: thumb.top
        anchors.right: thumb.right
        anchors.margins: 6
        width: 20
        height: 20
        radius: 10
        color: "#0A84FF"
        border.width: 1.5
        border.color: "white"
        visible: root.applied

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "white"
            font.pixelSize: 11
            font.bold: true
        }
    }

    Rectangle {
        anchors.left: thumb.left
        anchors.bottom: thumb.bottom
        anchors.margins: 6
        width: 22
        height: 22
        radius: 11
        color: Qt.rgba(0, 0, 0, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.4)
        visible: root.isVideo

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            text: "▶"
            color: "white"
            font.pixelSize: 9
        }
    }

    Text {
        anchors.top: thumb.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 8
        text: root.name
        color: Qt.rgba(1, 1, 1, 0.85)
        font.pixelSize: 12
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.tapped()
        onDoubleClicked: root.activated()
    }
}
