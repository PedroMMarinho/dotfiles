pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Singleton {
    id: root

    // Drives the compositor-enforced session lock.
    property bool locked: false

    // Shared password buffer so every monitor mirrors what's being typed.
    property string passwordDraft: ""

    // Auth state, shared across all per-monitor surfaces.
    property bool authenticating: false
    property bool failed: false
    property string statusText: "Enter Password"

    // Internal buffer of the password currently being verified.
    property string _pending: ""

    // True between a lock request and the moment we actually engage the
    // compositor lock (once the wallpaper is decoded), so nothing shows black.
    property bool _armed: false

    // Set once the fresh `awww query` for this lock request has returned, so we
    // never engage using a stale wallpaper path (e.g. right after switching it).
    property bool _queryDone: false

    // Per-output wallpaper paths, parsed from `awww query` (output name -> path).
    property var wallpapers: ({})

    // Flat list of the wallpaper paths, for the preloader below.
    property var wallpaperPaths: {
        const out = [];
        for (const k in wallpapers)
            out.push(wallpapers[k]);
        return out;
    }

    // Lock-screen status tray data (polled only while locked).
    property string keyboardLayout: "U.S."
    property int batteryPercent: -1
    property string batteryStatus: ""
    property int wifiSignal: -1 // -1 = unknown/disconnected

    // Emitted on a failed/errored attempt so surfaces can shake + clear.
    signal failedPulse()

    IpcHandler {
        target: "lock"

        function lock(): void {
            if (root.locked || root._armed)
                return;
            root._armed = true;             // engage once the fresh wallpaper is ready
            root._queryDone = false;
            wallpaperQuery.running = true;  // get the CURRENT wallpaper first
            armFallback.restart();          // ...but never hang if it can't load
        }
        function unlock(): void { root.locked = false; } // TEMPORARY test escape hatch; removed before commit
    }

    // Engages the real compositor lock, but only once the wallpaper primer has
    // decoded — so the lock surface's first frame is fully painted and the
    // desktop stays up (no black gap) until we're ready to show it.
    function _tryEngage(): void {
        if (!root._armed || !root._queryDone)
            return;
        if (primer.status === Image.Ready || root.wallpaperPaths.length === 0)
            root._engage();
    }

    function _engage(): void {
        if (!root._armed)
            return;
        root._armed = false;
        armFallback.stop();
        root.locked = true;
    }

    // Decodes the primary wallpaper into the pixmap cache; its readiness is the
    // gate for engaging the lock (the surface reuses the same cached pixmap).
    Image {
        id: primer
        visible: false
        cache: true
        asynchronous: true
        source: root.wallpaperPaths.length > 0 ? "file://" + root.wallpaperPaths[0] : ""
        onStatusChanged: root._tryEngage()
    }

    // Safety net: if the query/decode stalls, lock anyway rather than hang.
    Timer {
        id: armFallback
        interval: 800
        onTriggered: root._engage()
    }

    // Asks the awww daemon which wallpaper each output is displaying, so the
    // lock surface can reuse the live desktop wallpaper per monitor.
    Process {
        id: wallpaperQuery
        command: ["awww", "query"]

        stdout: SplitParser {
            // One line per output, e.g.:
            //   ": eDP-1: 1366x768, scale: 1, currently displaying: image: /path.png"
            onRead: line => {
                const nameM = line.match(/^:?\s*([A-Za-z0-9._-]+):/);
                const imgM = line.match(/image:\s*(.+?)\s*$/);
                if (nameM && imgM) {
                    const map = Object.assign({}, root.wallpapers);
                    map[nameM[1]] = imgM[1];
                    root.wallpapers = map;
                }
            }
        }

        // The map now reflects the CURRENT wallpaper; let the primer decode it
        // (if it changed) and engage the lock once it's ready.
        onExited: {
            root._queryDone = true;
            root._tryEngage();
        }
    }

    // Keep every output's wallpaper decoded in Qt's pixmap cache while the shell
    // runs, so the lock surface's very first frame already has the wallpaper
    // instead of decoding it from scratch on lock (the black/gradient flash).
    // These never render — the load alone is enough to warm QQuickPixmapCache.
    Instantiator {
        model: root.wallpaperPaths
        delegate: Image {
            required property string modelData
            source: modelData ? "file://" + modelData : ""
            cache: true
            asynchronous: true
            visible: false
        }
    }

    // Maps an fcitx5 input-method unique name to a short macOS-style label.
    function _fcitxLabel(name: string): string {
        if (!name)
            return "U.S.";
        const kb = name.match(/^keyboard-(.+)$/);
        if (kb) {
            const map = {
                "us": "U.S.",
                "us-intl": "U.S.",
                "gb": "U.K.",
                "pt": "PT",
                "br": "BR",
                "es": "ES",
                "fr": "FR",
                "de": "DE"
            };
            if (map[kb[1]] !== undefined)
                return map[kb[1]];
            return kb[1].split("-")[0].toUpperCase();
        }
        // Non-keyboard input method (e.g. pinyin, mozc): first letters.
        return name.substring(0, 2).toUpperCase();
    }

    // Active input method / layout via fcitx5.
    Process {
        id: kbQuery
        command: ["fcitx5-remote", "-n"]
        stdout: SplitParser {
            onRead: line => root.keyboardLayout = root._fcitxLabel(line.trim())
        }
    }

    // Cycles the input layout using the same script bound to MOD+SPACE on the
    // desktop (which can't fire while the compositor holds the session lock).
    Process {
        id: kbCycle
        command: ["sh", "-c", "$HOME/.config/hypr/scripts/Keyboard.sh"]
        onExited: kbQuery.running = true // refresh the tray label
    }

    // Invoked by a surface when the user clicks the keyboard tray group.
    function cycleKeyboard(): void {
        if (!kbCycle.running)
            kbCycle.running = true;
    }

    // Battery capacity + charge status from sysfs.
    Process {
        id: batQuery
        command: ["sh", "-c", "cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); st=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); echo \"$cap|$st\""]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("|");
                root.batteryPercent = parseInt(parts[0]) || 0;
                root.batteryStatus = (parts[1] || "").trim();
            }
        }
    }

    // Wi-Fi signal strength (0-100) of the active connection, -1 if none.
    Process {
        id: wifiQuery
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; f=1} END{if(!f) print \"-1\"}'"]
        stdout: SplitParser {
            onRead: line => root.wifiSignal = parseInt(line.trim())
        }
    }

    // Refresh tray data on lock and every few seconds while locked.
    Timer {
        interval: 5000
        repeat: true
        running: root.locked
        triggeredOnStart: true
        onTriggered: {
            kbQuery.running = true;
            batQuery.running = true;
            wifiQuery.running = true;
        }
    }

    // Called by a surface when the user submits the password field.
    function submit(password: string): void {
        if (root.authenticating || password.length === 0)
            return;
        root._pending = password;
        root.authenticating = true;
        root.failed = false;
        root.statusText = "Authenticating…";
        pam.start();
    }

    PamContext {
        id: pam
        config: "login"

        // PAM prompts for the password; feed it the buffered value.
        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root._pending);
        }

        onCompleted: (result) => {
            root.authenticating = false;
            root._pending = "";
            if (result === PamResult.Success) {
                root.failed = false;
                root.passwordDraft = "";
                root.statusText = "Enter Password";
                root.locked = false;
            } else {
                root.failed = true;
                root.passwordDraft = ""; // clear the field on every monitor
                root.statusText = (result === PamResult.MaxTries)
                    ? "Too many attempts. Try again."
                    : "Incorrect password. Try again.";
                root.failedPulse();
            }
        }

        onError: (error) => {
            root.authenticating = false;
            root._pending = "";
            root.failed = true;
            root.passwordDraft = ""; // clear the field on every monitor
            root.statusText = "Authentication error.";
            root.failedPulse();
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        Surface {}
    }

    function init() {
        wallpaperQuery.running = true; // warm the wallpaper map at startup
    }
}
