pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Freeze-first selection overlay: one window per monitor. The controller
// hides the real cursor (cursor:invisible) for the whole session, so these
// overlays draw the fake cursors. Once controller.frozen flips, each one
// displays its monitor's slice of the frozen master and the selection UI.
Scope {
    id: root

    required property var controller

    readonly property var origin: controller.layoutOrigin()

    // Quickshell's Hyprland objects cache their IPC data and only update it
    // on request; without this refresh, most toplevels carry stale or empty
    // lastIpcObject fields and the snapshot filters everything out. The
    // session's settle+grab (~200ms) gives the async replies ample time to
    // land before the frozen snapshot reads them.
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
    }

    // Global pointer position in layout coordinates, shared across monitors
    // so highlights and fake cursors render on whichever screen they touch.
    property real pointerX: -1
    property real pointerY: -1

    // Content boxes of every selectable window, snapshotted the moment the
    // frame froze (matches what the master image shows), sorted topmost
    // first. No live tracking: the frame is frozen, so is the window list.
    property var windows: []

    // The box the dim layer punches out and the ring draws around:
    // hovered window (window mode) or drag rectangle (crop mode). Global
    // layout coordinates, {x, y, w, h, radius}, or null.
    property var selection: null

    // Crop-mode drag, in global layout coordinates. A Wayland pointer grab
    // keeps delivering events to the pressed surface even past its edge, so
    // a drag can span monitors.
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0

    Connections {
        target: root.controller

        function onFrozenChanged() {
            if (!root.controller.frozen)
                return;
            // The real cursor is hidden for the whole session; start the
            // fake one where the pointer actually is instead of offscreen.
            if (root.pointerX < 0 && root.controller.seedX >= 0) {
                root.pointerX = root.controller.seedX;
                root.pointerY = root.controller.seedY;
            }
            if (root.controller.mode === "window")
                root.snapshotWindows();
        }
    }

    function selectable(toplevel) {
        const c = toplevel.lastIpcObject;
        if (!c || !c.mapped || c.hidden)
            return false;
        const ws = toplevel.workspace;
        if (!ws)
            return false;
        if (c.pinned)
            return true;
        // Behind a fullscreen window everything is covered; only the
        // fullscreen window itself is a valid pick.
        if (ws.hasFullscreen && c.fullscreen === 0)
            return false;
        // Shown special workspaces don't report active; match them against
        // their monitor's current special workspace instead.
        if (ws.id < 0) {
            const mon = ws.monitor ? ws.monitor.lastIpcObject : null;
            return (mon && mon.specialWorkspace) ? mon.specialWorkspace.id === ws.id : false;
        }
        return ws.active;
    }

    // Approximate stacking: special > fullscreen > pinned > floating > tiled,
    // most recently focused first within a tier. hyprctl exposes no true
    // z-order, but tiled windows never overlap, so this only breaks ties
    // between the layers that do.
    function stackRank(c) {
        return (c.workspace.id < 0 ? 8 : 0)
            + (c.fullscreen !== 0 ? 4 : 0)
            + (c.pinned ? 2 : 0)
            + (c.floating ? 1 : 0);
    }

    // hyprctl reports at/size including Hyprland's border ring; shrink so
    // the border stays out of the capture. True fullscreen (2) windows are
    // borderless and unrounded.
    function contentBox(c) {
        const b = c.fullscreen === 2 ? 0 : root.controller.borderSize;
        return {
            x: c.at[0] + b,
            y: c.at[1] + b,
            w: c.size[0] - 2 * b,
            h: c.size[1] - 2 * b,
            radius: c.fullscreen === 2 ? 0 : root.controller.rounding
        };
    }

    function snapshotWindows() {
        const wins = Hyprland.toplevels.values
            .filter(t => root.selectable(t))
            .map(t => t.lastIpcObject);
        wins.sort((a, b) => {
            const byRank = root.stackRank(b) - root.stackRank(a);
            return byRank !== 0 ? byRank : a.focusHistoryID - b.focusHistoryID;
        });
        root.windows = wins.map(c => root.contentBox(c));
        root.updateHover();
    }

    function windowAt(gx, gy) {
        // The list is topmost-first, so the first hit wins.
        return root.windows.find(b =>
            gx >= b.x && gx < b.x + b.w && gy >= b.y && gy < b.y + b.h) || null;
    }

    function updateHover() {
        const hit = root.pointerX >= 0
            ? root.windowAt(root.pointerX, root.pointerY) : null;
        root.selection = hit;
    }

    function pointerMoved(gx, gy) {
        root.pointerX = gx;
        root.pointerY = gy;
        if (root.controller.mode === "window" && root.controller.frozen)
            root.updateHover();
        else if (root.dragging)
            root.updateDrag(gx, gy);
    }

    function confirm() {
        // Clicking empty desktop keeps the picker open, like macOS.
        if (!root.selection)
            return;
        const s = root.selection;
        root.controller.finishSelection(
            Math.round(s.w) + "x" + Math.round(s.h)
            + "+" + Math.round(s.x - root.origin.x)
            + "+" + Math.round(s.y - root.origin.y));
    }

    function beginDrag(gx, gy) {
        root.dragging = true;
        root.dragX = gx;
        root.dragY = gy;
        root.selection = null;
    }

    function updateDrag(gx, gy) {
        root.selection = {
            x: Math.min(root.dragX, gx),
            y: Math.min(root.dragY, gy),
            w: Math.abs(gx - root.dragX),
            h: Math.abs(gy - root.dragY),
            radius: 0
        };
    }

    function endDrag() {
        root.dragging = false;
        const s = root.selection;
        // A sub-4px drag is a stray click: clear it and stay open.
        if (s && s.w >= 4 && s.h >= 4)
            root.confirm();
        else
            root.selection = null;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay

            required property var modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell:screenshot-overlay"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // root.selection translated into this screen's coordinates, or
            // null while it doesn't touch this screen.
            readonly property var localBox: {
                const b = root.selection;
                if (!b)
                    return null;
                if (b.x + b.w <= modelData.x || b.x >= modelData.x + overlay.width
                    || b.y + b.h <= modelData.y || b.y >= modelData.y + overlay.height)
                    return null;
                return { x: b.x - modelData.x, y: b.y - modelData.y,
                         w: b.w, h: b.h, radius: b.radius };
            }
            // Last non-null box, so the highlight keeps its geometry while
            // fading out instead of collapsing to 0x0.
            property var restingBox: ({ x: 0, y: 0, w: 0, h: 0, radius: 0 })
            onLocalBoxChanged: {
                if (localBox)
                    restingBox = localBox;
            }

            // Frozen frame slice for this monitor. Never shown in full mode —
            // full captures straight to the target file with no UI.
            Image {
                anchors.fill: parent
                visible: root.controller.frozen && root.controller.mode !== "full"
                source: root.controller.frozen ? "file://" + root.controller.masterPath : ""
                sourceClipRect: Qt.rect(
                    overlay.modelData.x - root.origin.x,
                    overlay.modelData.y - root.origin.y,
                    overlay.width, overlay.height)
                cache: false
            }

            // Everything below only exists once the master is on disk; any
            // earlier and it would be baked into the freeze-grab itself.
            Item {
                id: ui

                anchors.fill: parent
                visible: root.controller.frozen && root.controller.mode !== "full"

                // Mask that cuts the selection out of the dim layer, leaving
                // it at full brightness. Rendered offscreen only.
                Item {
                    id: holeMask

                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        id: hole

                        x: overlay.restingBox.x
                        y: overlay.restingBox.y
                        width: overlay.restingBox.w
                        height: overlay.restingBox.h
                        radius: overlay.restingBox.radius
                        color: "black"
                        opacity: overlay.localBox ? 1 : 0

                        // Disabled while dragging: the crop rubber band must
                        // track the pointer exactly, not lag 160ms behind it.
                        Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on y { enabled: !root.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on width { enabled: !root.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on height { enabled: !root.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on radius { enabled: !root.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }

                // Dim everywhere except the hole.
                Rectangle {
                    anchors.fill: parent
                    color: "#66000000"
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskInverted: true
                        maskSource: holeMask
                    }
                }

                // Selection wash and ring, riding on the hole's animated geometry.
                Rectangle {
                    x: hole.x
                    y: hole.y
                    width: hole.width
                    height: hole.height
                    radius: hole.radius
                    opacity: hole.opacity
                    color: "#22FFFFFF"
                    border.color: "#FFFFFF"
                    border.width: 2
                }

                // Fake cursor: the real one is blanked, we draw our own.
                // Camera glyph in window mode (macOS-style).
                Image {
                    visible: root.controller.mode === "window"
                    source: "camera.svg"
                    // 2x the SVG's 22x17 intrinsic size, rasterized sharp.
                    sourceSize.width: 24
                    x: root.pointerX - overlay.modelData.x - width / 2
                    y: root.pointerY - overlay.modelData.y - height / 2
                }

                // Crosshair fake cursor for crop mode: full-span hairlines.
                Rectangle {
                    visible: root.controller.mode === "crop"
                    x: root.pointerX - overlay.modelData.x
                    y: 0
                    width: 1
                    height: parent.height
                    color: "#CCFFFFFF"
                }
                Rectangle {
                    visible: root.controller.mode === "crop"
                    x: 0
                    y: root.pointerY - overlay.modelData.y
                    width: parent.width
                    height: 1
                    color: "#CCFFFFFF"
                }

                // WxH readout riding the selection's bottom-right corner.
                Rectangle {
                    visible: root.controller.mode === "crop" && overlay.localBox !== null
                    x: hole.x + hole.width + 8
                    y: hole.y + hole.height + 8
                    width: sizeText.implicitWidth + 12
                    height: sizeText.implicitHeight + 6
                    radius: 4
                    color: "#CC1A1A1A"

                    Text {
                        id: sizeText

                        anchors.centerIn: parent
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.family: "monospace"
                        text: root.selection
                            ? Math.round(root.selection.w) + " x " + Math.round(root.selection.h)
                            : ""
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.BlankCursor
                focus: true

                onEntered: root.pointerMoved(
                    overlay.modelData.x + mouseX, overlay.modelData.y + mouseY)
                onPositionChanged: mouse => root.pointerMoved(
                    overlay.modelData.x + mouse.x, overlay.modelData.y + mouse.y)
                onPressed: mouse => {
                    if (mouse.button === Qt.LeftButton
                        && root.controller.mode === "crop" && root.controller.frozen)
                        root.beginDrag(overlay.modelData.x + mouse.x,
                                       overlay.modelData.y + mouse.y);
                }
                onReleased: mouse => {
                    if (mouse.button === Qt.LeftButton && root.dragging)
                        root.endDrag();
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        root.controller.cancelSession();
                    else if (root.controller.mode === "window" && root.controller.frozen)
                        root.confirm();
                }

                Keys.onEscapePressed: root.controller.cancelSession()
            }
        }
    }
}
