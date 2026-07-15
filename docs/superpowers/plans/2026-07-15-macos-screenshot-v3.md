# macOS Screenshot v3 (Full-QML Freeze-First) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bash-orchestrated screenshot tool with a pure-QML freeze-first pipeline where the saved capture is cropped from a cursor-free frozen master image.

**Architecture:** Controller.qml (Quickshell singleton) owns a small state machine (`idle → freezing → frozen/selecting → done`) and runs grim/magick/wl-copy/paplay via `Quickshell.Io` Process objects. A per-monitor SelectionOverlay blanks the system cursor while mapped (so no cursor can composite into grim's frame), displays the frozen master after the grab, and reports a master-relative crop geometry back. `screenshot.sh`, the FIFO handoff, and the `screenshot-camera` cursor theme are deleted.

**Tech Stack:** Quickshell 0.3.0 (QtQuick, Quickshell.Io, Quickshell.Wayland, Quickshell.Hyprland), grim, ImageMagick (`magick`), wl-clipboard, jq, hyprctl, paplay/pw-play.

**Spec:** `docs/superpowers/specs/2026-07-15-macos-screenshot-v3-design.md`

## Global Constraints

- Monitor scale = 1 assumed: Hyprland logical coordinates == grim pixel coordinates.
- Save path format exactly: `$HOME/Pictures/Screenshots/Screenshot YYYY-MM-DD at HH.MM.SS.png`.
- IPC target name stays `screenshot`; keybind keys stay `mainMod+ALT+3` (full), `mainMod+ALT+4` (window), `mainMod+SHIFT+S` (crop).
- Thumbnail behavior, shutter sound, and clipboard copy unchanged from v2.
- Scratch master lives at the fixed path `/tmp/quickshell-screenshot-master.png` and must be deleted on every exit path.
- The repo is stow-managed: `configs/` stows into `$HOME`. After creating new files under `configs/`, verify they are visible at `~/.config/...` (re-run `stow configs` from the repo root if not).
- Quickshell hot-reloads QML on file change. If a change doesn't take effect, check `qs log` for QML errors before anything else.
- The dim layer, selection UI, and fake cursors must be gated on `controller.frozen` — anything visible before the freeze-grab would be baked into the master.
- No `hyprctl` cursor keywords, no `no_hardware_cursors` toggling, no cursor-theme swapping anywhere in v3.

---

### Task 1: Controller pipeline rewrite + cursor-hiding overlay skeleton (full mode end-to-end)

**Files:**
- Modify (full rewrite): `configs/.config/quickshell/screenshot/Controller.qml`
- Create: `configs/.config/quickshell/screenshot/SelectionOverlay.qml`
- Unchanged but interface-relevant: `configs/.config/quickshell/screenshot/Thumbnail.qml` (consumes `controller.file`, `controller.revealed`, `hold()`, `release()`, `openEditor()`)

**Interfaces:**
- Consumes: existing Thumbnail.qml contract listed above; `qs ipc call screenshot -- shoot <mode>` from the CLI.
- Produces (later tasks rely on these exact names):
  - `Controller.mode: string` — `""` (idle) or `"full" | "window" | "crop"`
  - `Controller.selecting: bool` (readonly, `mode !== ""`) — overlays are loaded while true
  - `Controller.frozen: bool` — master image is on disk; overlays may show UI
  - `Controller.masterPath: string` — `/tmp/quickshell-screenshot-master.png`
  - `Controller.borderSize: int`, `Controller.rounding: int` — hyprctl values fetched at shoot time
  - `Controller.layoutOrigin(): {x: real, y: real}` — top-left of the monitor layout bounding box (master pixel `(0,0)`)
  - `Controller.finishSelection(geometry: string)` — `"WxH+X+Y"` in **master-relative pixels**; crops, saves, copies, plays sound, shows thumbnail
  - `Controller.cancelSession()` — tears down overlays, deletes scratch, saves nothing

- [ ] **Step 1: Rewrite Controller.qml**

Replace the entire file with:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- thumbnail state (unchanged behavior from v2) ----
    // Absolute path of the capture currently shown by the thumbnail.
    property string file: ""
    // isOpen keeps the window loaded; revealed drives the slide animation.
    property bool isOpen: false
    property bool revealed: false

    // ---- capture session state ----
    // A session walks: idle (mode === "") -> freezing -> frozen -> done/cancelled.
    property string mode: ""                  // "" | "full" | "window" | "crop"
    // Overlays are mapped for every mode: even "full" needs them, because a
    // mapped surface with a blank cursor is what keeps the pointer out of
    // the compositor's frame during the grab.
    readonly property bool selecting: mode !== ""
    // True once the master (or the full-mode file) has been written.
    property bool frozen: false
    readonly property string masterPath: "/tmp/quickshell-screenshot-master.png"
    property int borderSize: 0
    property int rounding: 0

    readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string soundPath:
        Qt.resolvedUrl("shutter.oga").toString().replace("file://", "")
    property string pendingFile: ""

    IpcHandler {
        target: "screenshot"

        function shoot(mode: string): void { root.startSession(mode); }
        function cancel(): void { root.cancelSession(); }
        function show(path: string): void { root.showThumb(path); }
        // Instant hide, no slide-out.
        function hide(): void { root.hideThumb(); }
    }

    function startSession(m) {
        if (m !== "full" && m !== "window" && m !== "crop") {
            console.error("screenshot: unknown mode:", m);
            return;
        }
        if (root.mode !== "")
            cancelSession();              // a new invocation replaces a stuck one
        hideThumb();                      // a previous thumbnail must never be captured
        optsProc.running = true;          // border/rounding for the window picker
        root.frozen = false;
        root.mode = m;                    // maps the overlays (transparent, blank cursor)
        settleTimer.restart();
    }

    // The blank cursor and the hidden thumbnail need a moment to actually
    // leave the compositor's frame before grim samples it.
    Timer {
        id: settleTimer
        interval: 80
        onTriggered: {
            if (root.mode === "full") {
                root.pendingFile = root.targetFile();
                grimProc.command = ["sh", "-c", 'mkdir -p "$0" && grim "$1"',
                    root.saveDir, root.pendingFile];
            } else {
                grimProc.command = ["grim", root.masterPath];
            }
            grimProc.running = true;
        }
    }

    Process {
        id: grimProc
        onExited: (exitCode, exitStatus) => {
            if (root.mode === "") {
                // Cancelled while grim was running: discard whatever it wrote.
                Quickshell.execDetached(["rm", "-f", root.masterPath, root.pendingFile]);
                return;
            }
            if (exitCode !== 0) {
                root.failSession("grim exited " + exitCode);
                return;
            }
            if (root.mode === "full") {
                root.mode = "";           // unmap overlays
                root.postProcess(root.pendingFile);
            } else {
                root.frozen = true;       // overlays show the frozen frame + UI
            }
        }
    }

    // geometry is "WxH+X+Y" in master-relative pixels (layout origin removed).
    function finishSelection(geometry) {
        if (root.mode === "" || !root.frozen)
            return;
        root.mode = "";                   // unmap immediately; the pixels are on disk
        root.frozen = false;
        root.pendingFile = root.targetFile();
        magickProc.command = ["sh", "-c",
            'mkdir -p "$3" && magick "$0" -crop "$1" +repage "$2"; s=$?; rm -f "$0"; exit $s',
            root.masterPath, geometry, root.pendingFile, root.saveDir];
        magickProc.running = true;
    }

    function cancelSession() {
        if (root.mode === "")
            return;
        root.mode = "";
        root.frozen = false;
        Quickshell.execDetached(["rm", "-f", root.masterPath]);
    }

    function failSession(msg) {
        console.error("screenshot:", msg);
        cancelSession();
    }

    Process {
        id: magickProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.failSession("magick exited " + exitCode);
                return;
            }
            root.postProcess(root.pendingFile);
        }
    }

    Process {
        id: optsProc
        command: ["sh", "-c",
            "hyprctl getoption general:border_size -j | jq .int; hyprctl getoption decoration:rounding -j | jq .int"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.borderSize = parseInt(lines[0], 10) || 0;
                root.rounding = parseInt(lines[1], 10) || 0;
            }
        }
    }

    function postProcess(f) {
        Quickshell.execDetached(["sh", "-c", 'wl-copy < "$0"', f]);
        Quickshell.execDetached(["sh", "-c",
            'command -v paplay >/dev/null && exec paplay "$0"; command -v pw-play >/dev/null && exec pw-play "$0"',
            root.soundPath]);
        showThumb(f);
    }

    function targetFile() {
        const d = new Date();
        const pad = n => String(n).padStart(2, "0");
        return root.saveDir + "/Screenshot " + d.getFullYear() + "-" + pad(d.getMonth() + 1)
            + "-" + pad(d.getDate()) + " at " + pad(d.getHours()) + "." + pad(d.getMinutes())
            + "." + pad(d.getSeconds()) + ".png";
    }

    // Top-left corner of the monitor layout's bounding box: grim's master
    // image starts here, so master pixels = global coords minus this origin.
    function layoutOrigin() {
        let ox = Infinity, oy = Infinity;
        for (const s of Quickshell.screens) {
            ox = Math.min(ox, s.x);
            oy = Math.min(oy, s.y);
        }
        return { x: isFinite(ox) ? ox : 0, y: isFinite(oy) ? oy : 0 };
    }

    // ---- thumbnail plumbing (unchanged behavior from v2) ----

    function showThumb(path) {
        unloadTimer.stop();
        root.file = path;
        root.isOpen = true;
        root.revealed = true;
        dismissTimer.restart();
    }

    function hideThumb() {
        dismissTimer.stop();
        unloadTimer.stop();
        root.revealed = false;
        root.isOpen = false;
    }

    // macOS keeps the thumbnail around while the pointer is over it.
    function hold() { dismissTimer.stop(); }
    function release() { dismissTimer.restart(); }

    function dismiss() {
        dismissTimer.stop();
        root.revealed = false;
        unloadTimer.restart();
    }

    function openEditor() {
        Quickshell.execDetached({ command: ["swappy", "-f", root.file] });
        dismiss();
    }

    Timer {
        id: dismissTimer
        interval: 5000
        onTriggered: root.dismiss()
    }

    // Slightly longer than the slide-out animation in Thumbnail.qml.
    Timer {
        id: unloadTimer
        interval: 300
        onTriggered: root.isOpen = false
    }

    LazyLoader {
        active: root.isOpen

        Thumbnail {
            controller: root
        }
    }

    LazyLoader {
        active: root.selecting

        SelectionOverlay {
            controller: root
        }
    }

    function init() {
    }
}
```

- [ ] **Step 2: Create SelectionOverlay.qml (skeleton)**

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Freeze-first selection overlay: one window per monitor. While mapped it
// blanks the system cursor — no pointer, hardware or software, gets
// composited into grim's frame. Once controller.frozen flips, it displays
// this monitor's slice of the frozen master and the mode's selection UI.
Scope {
    id: root

    required property var controller

    readonly property var origin: controller.layoutOrigin()

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

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.BlankCursor
                focus: true

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        root.controller.cancelSession();
                }

                Keys.onEscapePressed: root.controller.cancelSession()
            }
        }
    }
}
```

- [ ] **Step 3: Verify the files are stow-visible and the config loads**

Run:
```bash
test -e ~/.config/quickshell/screenshot/SelectionOverlay.qml && echo visible || (cd ~/dotfiles && stow configs && echo restowed)
qs log 2>/dev/null | tail -20
```
Expected: `visible` (or `restowed`), and no QML errors mentioning `screenshot` in the log tail.

- [ ] **Step 4: Smoke-test full mode end-to-end**

Run:
```bash
qs ipc call screenshot -- shoot full
sleep 1
command ls -t "$HOME/Pictures/Screenshots" | head -1
wl-paste --list-types
test -f /tmp/quickshell-screenshot-master.png && echo "STALE SCRATCH" || echo "scratch clean"
```
Expected: a new `Screenshot 2026-07-15 at *.png` listed, `image/png` among clipboard types, `scratch clean`, thumbnail pops on screen, shutter sound plays.

- [ ] **Step 5: Smoke-test cancel and idle no-ops**

Run:
```bash
qs ipc call screenshot -- cancel     # idle: must be a silent no-op
qs ipc call screenshot -- shoot bogus
qs log 2>/dev/null | tail -3
```
Expected: no crash, log tail contains `screenshot: unknown mode: bogus`.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add configs/.config/quickshell/screenshot/Controller.qml configs/.config/quickshell/screenshot/SelectionOverlay.qml
git commit -m "screenshot v3: full-QML pipeline, cursor-blanking overlay, full mode"
```

---

### Task 2: Frozen-frame window-pick mode

**Files:**
- Create: `configs/.config/quickshell/screenshot/camera.png` (extracted from the Xcursor theme)
- Modify: `configs/.config/quickshell/screenshot/SelectionOverlay.qml`

**Interfaces:**
- Consumes: `controller.mode`, `controller.frozen`, `controller.borderSize`, `controller.rounding`, `controller.finishSelection(geometry)`, `controller.cancelSession()`, `root.origin` from Task 1.
- Produces (Task 3 relies on these exact names on the Scope root):
  - `root.pointerX: real`, `root.pointerY: real` — global layout coords of the pointer, shared across monitors
  - `root.selection: var` — `{x, y, w, h, radius}` in global layout coords, or `null`; the dim/hole/ring renders whatever this holds
  - `root.confirm()` — submits `root.selection` to `controller.finishSelection` as master-relative `WxH+X+Y`
  - `root.pointerMoved(gx, gy)` — single entry point for pointer motion, dispatches per mode

- [ ] **Step 1: Extract the camera glyph as a PNG asset**

Run:
```bash
tmp=$(mktemp -d)
xcur2png -d "$tmp" -c "$tmp/conf" ~/dotfiles/cursor/.icons/screenshot-camera/cursors/camera
cp "$tmp/camera_001.png" ~/dotfiles/configs/.config/quickshell/screenshot/camera.png
magick identify ~/dotfiles/configs/.config/quickshell/screenshot/camera.png
```
Expected: `camera.png PNG 48x48 ...` (the 48px frame of the theme).

- [ ] **Step 2: Add window snapshot + hit-testing to the Scope root**

In `SelectionOverlay.qml`, add `import Quickshell.Hyprland` to the imports, then insert after `readonly property var origin: ...`:

```qml
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

    Connections {
        target: root.controller

        function onFrozenChanged() {
            if (root.controller.frozen && root.controller.mode === "window")
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
        root.selection = root.pointerX >= 0
            ? root.windowAt(root.pointerX, root.pointerY) : null;
    }

    function pointerMoved(gx, gy) {
        root.pointerX = gx;
        root.pointerY = gy;
        if (root.controller.mode === "window" && root.controller.frozen)
            root.updateHover();
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
```

- [ ] **Step 3: Add the dim/hole/ring UI and camera fake-cursor to each overlay**

Inside the `PanelWindow`, insert between the frozen-frame `Image` and the `MouseArea`:

```qml
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

                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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
                    source: "camera.png"
                    x: root.pointerX - overlay.modelData.x - width / 2
                    y: root.pointerY - overlay.modelData.y - height / 2
                }
            }
```

Also add `import QtQuick.Effects` to the file's imports (MultiEffect needs it).

- [ ] **Step 4: Wire pointer motion and click-confirm into the MouseArea**

Replace the skeleton `MouseArea`'s handlers with:

```qml
                onEntered: root.pointerMoved(
                    overlay.modelData.x + mouseX, overlay.modelData.y + mouseY)
                onPositionChanged: mouse => root.pointerMoved(
                    overlay.modelData.x + mouse.x, overlay.modelData.y + mouse.y)
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        root.controller.cancelSession();
                    else if (root.controller.mode === "window" && root.controller.frozen)
                        root.confirm();
                }

                Keys.onEscapePressed: root.controller.cancelSession()
```

- [ ] **Step 5: Smoke-test window mode**

Run `qs ipc call screenshot -- shoot window`, then interactively:
- Screens freeze (open a playing video first to confirm the frame stops).
- Hovering windows slides the highlight between them; camera glyph follows the pointer; no system cursor visible.
- Click a window.

Then:
```bash
command ls -t "$HOME/Pictures/Screenshots" | head -1
magick identify "$HOME/Pictures/Screenshots/$(command ls -t "$HOME/Pictures/Screenshots" | head -1)"
test -f /tmp/quickshell-screenshot-master.png && echo "STALE SCRATCH" || echo "scratch clean"
```
Expected: new file whose dimensions match the clicked window's content box (window size minus 2×border), `scratch clean`, no cursor anywhere in the image.

- [ ] **Step 6: Smoke-test cancellation**

Run `qs ipc call screenshot -- shoot window`, press Escape. Then repeat and right-click. After each:
```bash
test -f /tmp/quickshell-screenshot-master.png && echo "STALE SCRATCH" || echo "scratch clean"
```
Expected: overlay closes, no new file, no sound, `scratch clean` both times.

- [ ] **Step 7: Commit**

```bash
cd ~/dotfiles
git add configs/.config/quickshell/screenshot/SelectionOverlay.qml configs/.config/quickshell/screenshot/camera.png
git commit -m "screenshot v3: frozen-frame window-pick mode with fake camera cursor"
```

---

### Task 3: Frozen-frame crop mode

**Files:**
- Modify: `configs/.config/quickshell/screenshot/SelectionOverlay.qml`

**Interfaces:**
- Consumes: `root.pointerX/Y`, `root.selection`, `root.confirm()`, `root.pointerMoved(gx, gy)` from Task 2; `controller.mode === "crop"`.
- Produces: nothing new for later tasks; crop mode is self-contained.

- [ ] **Step 1: Add drag state and handlers to the Scope root**

Insert after `property var selection: null`:

```qml
    // Crop-mode drag, in global layout coordinates. A Wayland pointer grab
    // keeps delivering events to the pressed surface even past its edge, so
    // a drag can span monitors.
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
```

Insert after `function confirm() {...}`:

```qml
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
```

And extend `pointerMoved` by adding the crop branch, so the whole function reads:

```qml
    function pointerMoved(gx, gy) {
        root.pointerX = gx;
        root.pointerY = gy;
        if (root.controller.mode === "window" && root.controller.frozen)
            root.updateHover();
        else if (root.dragging)
            root.updateDrag(gx, gy);
    }
```

- [ ] **Step 2: Route press/release in the MouseArea**

Add to the `MouseArea` (alongside the Task 2 handlers):

```qml
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
```

- [ ] **Step 3: Add the crosshair fake-cursor and size readout to the `ui` Item**

Insert inside the `ui` Item, after the camera `Image`:

```qml
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
```

Note: in crop mode the hole animates with the same 160ms Behaviors as window mode, which would make the rubber band lag the pointer. Disable them while dragging by changing each `Behavior` in the `hole` Rectangle to include an `enabled` guard, e.g.:

```qml
                        Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
```

Apply the same `enabled: !root.dragging` to the `y`, `width`, `height`, and `radius` Behaviors (leave `opacity` as is).

- [ ] **Step 4: Smoke-test crop mode**

Run `qs ipc call screenshot -- shoot crop`, then interactively:
- Screens freeze; crosshair hairlines follow the pointer; no system cursor.
- Drag a region: dim punches out the rectangle live, readout shows `W x H`.
- Release.

Then:
```bash
command ls -t "$HOME/Pictures/Screenshots" | head -1
magick identify "$HOME/Pictures/Screenshots/$(command ls -t "$HOME/Pictures/Screenshots" | head -1)"
test -f /tmp/quickshell-screenshot-master.png && echo "STALE SCRATCH" || echo "scratch clean"
```
Expected: new file whose dimensions match the readout at release, `scratch clean`.

Also verify: a plain click (no drag) leaves the overlay open with nothing selected; Escape cancels cleanly; a drag from one monitor into the other produces a capture spanning both.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add configs/.config/quickshell/screenshot/SelectionOverlay.qml
git commit -m "screenshot v3: frozen-frame crop mode with crosshair and size readout"
```

---

### Task 4: Keybind rewire + delete screenshot.sh and the cursor theme

**Files:**
- Modify: `configs/.config/hypr/modules/keybinds.lua:58-60`
- Modify: `configs/.config/hypr/modules/variables.lua:42`
- Delete: `configs/.config/quickshell/screenshot/screenshot.sh`
- Delete: `cursor/.icons/screenshot-camera/` (whole theme; `cursor/` stow package)

**Interfaces:**
- Consumes: `qs ipc call screenshot -- shoot full|window|crop` from Task 1.
- Produces: final user-facing entry points; nothing downstream.

- [ ] **Step 1: Rewire the keybinds**

In `configs/.config/hypr/modules/keybinds.lua`, replace lines 58-60:

```lua
hl.bind(v.mainMod .. " + ALT + 3", hl.dsp.exec_cmd("qs ipc call screenshot -- shoot full"))
hl.bind(v.mainMod .. " + ALT + 4", hl.dsp.exec_cmd("qs ipc call screenshot -- shoot window"))
hl.bind(v.mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs ipc call screenshot -- shoot crop"))
```

In `configs/.config/hypr/modules/variables.lua`, delete line 42:

```lua
v.screenshotScript = home .. "/.config/quickshell/screenshot/screenshot.sh"
```

Verify nothing else references it:
```bash
grep -rn "screenshotScript" ~/dotfiles/configs/
```
Expected: no output.

- [ ] **Step 2: Delete screenshot.sh**

```bash
cd ~/dotfiles
git rm configs/.config/quickshell/screenshot/screenshot.sh
```

- [ ] **Step 3: Unstow and delete the camera cursor theme**

The fake-cursor Image replaced the theme. First confirm nothing outside the theme references it:

```bash
grep -rn "screenshot-camera" ~/dotfiles --exclude-dir=.git --exclude-dir=docs -l
```
Expected: only paths under `cursor/.icons/screenshot-camera` itself. If a Hyprland config or env file shows up, remove that reference too before proceeding. Then:

```bash
cd ~/dotfiles
stow -D cursor
command ls -A cursor/
```
If `cursor/` contains only `.icons/screenshot-camera`, remove the whole package; otherwise remove just the theme:

```bash
git rm -r cursor/.icons/screenshot-camera
find cursor -type d -empty -delete 2>/dev/null; true
```

- [ ] **Step 4: Reload Hyprland config and verify the binds live**

```bash
hyprctl reload
hyprctl binds | grep -A2 -i "shoot" | head -12
```
Expected: three binds whose exec lines contain `qs ipc call screenshot -- shoot`.

- [ ] **Step 5: Full-system UAT pass (human)**

- `mainMod+ALT+3`: instant full capture, no cursor in it, thumbnail + sound + clipboard.
- `mainMod+ALT+4`: freeze, camera cursor, highlight, click captures the content box.
- `mainMod+SHIFT+S`: freeze, crosshair, drag captures the region; cross-monitor drag works.
- Escape and right-click cancel from both interactive modes.
- Rapid double-press of a keybind doesn't wedge the state machine (second press replaces the first session).
- `command ls /tmp | grep quickshell-screenshot` after all of the above: empty.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add -A configs/.config/hypr/modules/keybinds.lua configs/.config/hypr/modules/variables.lua
git commit -m "screenshot v3: rewire keybinds to qs ipc, drop screenshot.sh and camera cursor theme"
```

---

## Self-Review Notes

- **Spec coverage:** freeze-first pipeline (T1-T3), separate modes preserved (T2/T3 + T4 binds), full-QML with script deleted (T1, T4), blank-cursor capture hygiene (T1), fake cursors (T2 camera, T3 crosshair), crop-from-master with no second capture (T1 `finishSelection`), error handling incl. mid-grab cancel guard (T1), scratch cleanup on all paths (T1), cursor theme deletion (T4), UAT list (T4 step 5). No gaps found.
- **Type consistency:** `finishSelection(geometry: string)`, `cancelSession()`, `layoutOrigin()`, `pointerMoved(gx, gy)`, `selection {x,y,w,h,radius}` used identically across tasks.
