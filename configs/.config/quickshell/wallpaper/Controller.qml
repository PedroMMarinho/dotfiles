pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property bool isOpen: false

    readonly property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string thumbCacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-thumbs"

    // Path currently applied on the desktop (seeded from `awww query`).
    property string currentPath: ""
    onCurrentPathChanged: rebuild()

    // Search filter; visibleEntries is rebuilt whenever it changes.
    property string query: ""
    onQueryChanged: rebuild()

    // Full scan results as JS objects: { name, path, fileUrl, thumbUrl, isVideo, thumbReady }
    property var allEntries: []

    // Skip model churn when a rescan finds the same files: reopening the
    // picker keeps existing delegates and their already-decoded thumbnails.
    property string scanFingerprint: ""

    // Monotonic scan generation: exits of Processes belonging to a replaced
    // scan must not touch the current model (same pattern as screenshot).
    property int scanGen: 0

    signal modelRebuilt()

    ListModel { id: visibleModel }
    property alias visibleEntries: visibleModel

    IpcHandler {
        target: "wallpaper"

        function open() { root.show(); }
        function close() { root.isOpen = false; }
        function toggle() { root.isOpen ? root.isOpen = false : root.show(); }
    }

    LazyLoader {
        active: root.isOpen
        Overlay {
            controller: root
        }
    }

    function show() {
        Hyprland.refreshMonitors();
        query = "";
        isOpen = true;
        rescan();
    }

    function rescan() {
        scanProc.running = false;
        scanProc.running = true;
        queryProc.running = false;
        queryProc.running = true;
    }

    Process {
        id: scanProc
        command: ["find", "-L", root.wallpapersDir, "-type", "f", "(",
            "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o", "-iname", "*.webp", "-o",
            "-iname", "*.bmp", "-o", "-iname", "*.gif", "-o",
            "-iname", "*.mp4", "-o", "-iname", "*.mkv", "-o",
            "-iname", "*.mov", "-o", "-iname", "*.webm", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.buildEntries(text)
        }
    }

    Process {
        id: queryProc
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image: (.*)$/m);
                if (m)
                    root.currentPath = m[1].trim();
            }
        }
    }

    function buildEntries(text) {
        if (text === scanFingerprint)
            return;
        scanFingerprint = text;
        scanGen++;

        const videoRe = /\.(mp4|mkv|mov|webm)$/i;
        const entries = [];
        const jobs = [];
        const files = text.trim().split("\n").filter(f => f.length > 0)
            .sort((a, b) => a.localeCompare(b));

        for (const path of files) {
            const rel = path.slice(wallpapersDir.length + 1);
            const isVideo = videoRe.test(path);
            const thumbPath = thumbCacheDir + "/" + rel.replace(/\//g, "_") + ".png";
            entries.push({
                name: rel.replace(/\.[^.]*$/, ""),
                path: path,
                fileUrl: "file://" + path,
                thumbUrl: "file://" + thumbPath,
                isVideo: isVideo,
                thumbReady: false
            });
            jobs.push({ entry: entries.length - 1, src: path, dst: thumbPath,
                        type: isVideo ? "video" : "image" });
        }

        allEntries = entries;
        thumbQueue = jobs;
        rebuild();
        nextThumb();
    }

    function rebuild() {
        const q = query.trim().toLowerCase();
        visibleModel.clear();
        const matches = allEntries.filter(e => !q || e.name.toLowerCase().includes(q));
        // Currently applied wallpaper goes first so the picker opens on it.
        for (const e of matches.filter(e => e.path === currentPath))
            visibleModel.append(e);
        for (const e of matches.filter(e => e.path !== currentPath))
            visibleModel.append(e);
        modelRebuilt();
    }

    property var thumbQueue: []

    function nextThumb() {
        if (thumbQueue.length === 0)
            return;
        const job = thumbQueue[0];
        thumbProc.entryIndex = job.entry;
        thumbProc.gen = scanGen;
        thumbProc.command = ["sh", "-c",
            '[ -f "$1" ] || { mkdir -p "$(dirname "$1")"; ' +
            'if [ "$2" = video ]; then ' +
            'ffmpeg -v error -y -i "$0" -ss 00:00:01.000 -vframes 1 ' +
            '-vf "scale=336:180:force_original_aspect_ratio=increase" "$1"; ' +
            'else magick "$0[0]" -resize 336x180^ "$1"; fi; }',
            job.src, job.dst, job.type];
        thumbProc.running = true;
    }

    Process {
        id: thumbProc

        property int entryIndex: -1
        property int gen: -1

        onExited: (exitCode, exitStatus) => {
            if (gen !== root.scanGen)
                return;
            root.thumbQueue = root.thumbQueue.slice(1);
            if (exitCode === 0) {
                root.allEntries[entryIndex].thumbReady = true;
                const path = root.allEntries[entryIndex].path;
                for (let i = 0; i < visibleModel.count; i++) {
                    if (visibleModel.get(i).path === path) {
                        visibleModel.setProperty(i, "thumbReady", true);
                        break;
                    }
                }
            }
            root.nextThumb();
        }
    }

    // Layer surfaces on the background layer stack newest-on-top, so every
    // switch maps the new wallpaper first and only then removes the old one:
    // no black gap and no flash of a stale image. The awww daemon is kept
    // alive behind videos (mpvpaper just covers it) and started with
    // --no-cache, since its startup cache restore is what used to flash the
    // previous image when switching from a video back to an image.
    function apply(path, isVideo) {
        if (isVideo) {
            // awww cannot play videos: map mpvpaper over whatever is showing,
            // then kill the previous mpvpaper instance once the new one is up.
            Quickshell.execDetached(["sh", "-c",
                'OLD=$(pgrep -x mpvpaper); ' +
                'setsid mpvpaper -o "load-scripts=no no-audio --loop" "*" "$0" >/dev/null 2>&1 & ' +
                'sleep 1; [ -n "$OLD" ] && kill $OLD 2>/dev/null',
                path]);
        } else {
            // Image over image: fast fade. Image under a video: swap silently
            // with no transition, then unveil it by killing mpvpaper.
            Quickshell.execDetached(["sh", "-c",
                'pgrep -x awww-daemon >/dev/null || { setsid awww-daemon --format xrgb --no-cache >/dev/null 2>&1 & sleep 0.5; }; ' +
                'if pgrep -x mpvpaper >/dev/null; then ' +
                'awww img "$0" --transition-type none; sleep 0.2; pkill -x mpvpaper 2>/dev/null; ' +
                'else exec awww img "$0" --transition-type fade --transition-duration 0.4 --transition-fps 60; fi',
                path]);
        }
        currentPath = path;
        isOpen = false;
    }

    // Scan and warm the thumbnail cache at shell startup so the first
    // open of the picker is instant.
    function init() {
        rescan();
    }
}
