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
    // Monotonic session id: a Process exit belonging to a replaced session
    // must be ignored, never treated as the live session's result.
    property int session: 0

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
        root.session++;
        root.pendingFile = "";
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
            grimProc.session = root.session;
            grimProc.running = true;
        }
    }

    Process {
        id: grimProc

        property int session: -1

        onExited: (exitCode, exitStatus) => {
            if (session !== root.session) {
                // A newer session replaced this grab. Its master will be
                // overwritten by the new grim; only clean up if idle.
                if (root.mode === "")
                    Quickshell.execDetached(["rm", "-f", root.masterPath]);
                return;
            }
            if (root.mode === "") {
                // Cancelled while grim was running: discard whatever it wrote.
                Quickshell.execDetached(root.pendingFile !== ""
                    ? ["rm", "-f", root.masterPath, root.pendingFile]
                    : ["rm", "-f", root.masterPath]);
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
        // Never pop the thumbnail into a session that is currently capturing.
        if (root.mode === "")
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
