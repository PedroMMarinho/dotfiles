pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness, watched rather than driven.
//
// The multimedia keys keep calling brightnessctl directly (see
// hypr/modules/keybinds.lua); this only notices the result, so brightness
// changed from anywhere else shows up too and the keys still work when the
// shell is not running.
//
// sysfs delivers no inotify events, so FileView/watchChanges never fires on
// these files -- polling is the only reliable option. One long-lived process
// reading a four-byte file at 10Hz costs nothing, and it writes to stdout only
// when the value actually changes, so QML wakes solely on real transitions.
Singleton {
    id: root

    readonly property string device: "/sys/class/backlight/nvidia_wmi_ec_backlight"

    property int raw: -1
    property int max: -1

    // 0..1, or -1 until the first reading lands.
    readonly property real value: root.max > 0 && root.raw >= 0 ? root.raw / root.max : -1

    Process {
        running: true
        command: ["sh", "-c",
            "max=$(cat " + root.device + "/max_brightness 2>/dev/null); " +
            "prev=''; while :; do " +
            "cur=$(cat " + root.device + "/brightness 2>/dev/null); " +
            "if [ \"$cur\" != \"$prev\" ]; then echo \"$cur|$max\"; prev=$cur; fi; " +
            "sleep 0.1; done"]

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split("|");
                const cur = parseInt(parts[0]);
                const max = parseInt(parts[1]);
                if (isNaN(cur) || isNaN(max) || max <= 0)
                    return;
                root.max = max;
                root.raw = cur;
            }
        }
    }
}
