pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property alias model: list.model
    property alias currentIndex: list.currentIndex
    property alias listItem: list
    property string appliedPath

    signal confirmed(string path, bool isVideo)

    implicitHeight: 126

    Rectangle {
        id: thumbMask
        width: 168
        height: 90
        radius: 10
        visible: false
    }

    ShaderEffectSource {
        id: thumbMaskTexture
        width: thumbMask.width
        height: thumbMask.height
        visible: false
        sourceItem: thumbMask
    }

    ListView {
        id: list
        // Shrink to content so a short list sits centered in the panel.
        // Computed from count and fixed delegate geometry (168 wide, 16
        // spacing, 16 header + 16 footer) instead of contentWidth, which
        // depends on the viewport width and would form a binding loop.
        width: Math.min(count > 0 ? count * 184 + 16 : 0, root.width)
        height: 126
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        orientation: ListView.Horizontal
        spacing: 16
        clip: true
        // Breathing room inside the clipped viewport so the selection ring
        // and shadow of the first/last thumbnails don't get cut off.
        header: Item { width: 16; height: 1 }
        footer: Item { width: 16; height: 1 }
        highlightRangeMode: ListView.ApplyRange
        // Clamped: during overlay creation width is briefly negative, and a
        // negative highlight begin makes the view scroll contentX past the
        // header, permanently clipping the first item.
        preferredHighlightBegin: Math.max(0, (width - 168) / 2)
        preferredHighlightEnd: preferredHighlightBegin + 168
        highlightMoveDuration: 260

        // Re-anchor once layout settles; range application during creation
        // leaves contentX stuck wherever the invalid geometry put it.
        onWidthChanged: if (width > 0) positionViewAtBeginning()

        delegate: ThumbnailDelegate {
            id: delegateItem
            maskProvider: thumbMaskTexture
            current: ListView.isCurrentItem
            applied: root.appliedPath === path
            onTapped: list.currentIndex = delegateItem.index
            onActivated: {
                list.currentIndex = delegateItem.index
                root.confirmed(delegateItem.path, delegateItem.isVideo)
            }
        }

        Keys.onReturnPressed: if (currentItem) root.confirmed(currentItem.path, currentItem.isVideo)
        Keys.onEnterPressed: if (currentItem) root.confirmed(currentItem.path, currentItem.isVideo)
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: qsTr("No wallpapers found")
        color: Qt.rgba(1, 1, 1, 0.6)
        font.pixelSize: 14
    }
}
