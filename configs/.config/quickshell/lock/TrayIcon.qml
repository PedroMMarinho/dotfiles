import QtQuick
import Quickshell

// A symbolic icon resolved from the active icon theme (WhiteSur-dark),
// rendered at a fixed box size so tray glyphs line up consistently.
Image {
    id: root

    property string iconName
    property real size: 16

    width: size
    height: size
    source: iconName ? Quickshell.iconPath(iconName) : ""
    sourceSize.width: Math.round(size * 2)
    sourceSize.height: Math.round(size * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
}
