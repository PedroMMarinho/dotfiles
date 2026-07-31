pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Battery polling and charge notifications live here rather than in the bar
// block, because Bar is instantiated once per screen (Variants over
// Quickshell.screens). A block-owned poller spawns one process per monitor and
// fires one notification per monitor -- three of each on this machine.
Singleton {
    id: root

    property int capacity: -1
    property string status: ""

    readonly property int lowThreshold: 20
    readonly property int criticalThreshold: 10

    // seeded stays false until the first poll lands, so a shell reload never
    // fires "charger disconnected" at you out of nowhere.
    property bool seeded: false
    property bool plugged: false
    property bool warnedLow: false
    property bool warnedCritical: false

    function checkNotifications() {
        if (status === "" || capacity < 0)
            return;

        // "Not charging" is plugged in but held at a charge limit -- treating
        // it as unplugged would fire a bogus disconnect every time the limit
        // is reached.
        const nowPlugged = status !== "Discharging";

        if (!seeded) {
            seeded = true;
            plugged = nowPlugged;
            // Seed the one-shots too: starting the shell at 8% unplugged
            // should not immediately warn about a level you already know.
            warnedLow = !nowPlugged && capacity <= lowThreshold;
            warnedCritical = !nowPlugged && capacity <= criticalThreshold;
            return;
        }

        if (nowPlugged !== plugged) {
            plugged = nowPlugged;
            if (nowPlugged) {
                warnedLow = false;
                warnedCritical = false;
                // Plugging in at a charge limit reports "Not charging", so do
                // not promise charging that will not happen.
                Notify.send("Charger connected",
                            capacity + "% — " + (status === "Charging" ? "charging" : "plugged in"),
                            root.icon, "normal");
            } else {
                Notify.send("Charger disconnected", capacity + "% remaining",
                            root.icon, "normal");
            }
            return;
        }

        if (nowPlugged)
            return;

        if (capacity <= criticalThreshold && !warnedCritical) {
            warnedCritical = true;
            warnedLow = true;
            Notify.send("Battery critically low",
                        capacity + "% remaining — plug in now", root.icon, "critical");
        } else if (capacity <= lowThreshold && !warnedLow) {
            warnedLow = true;
            Notify.send("Battery low", capacity + "% remaining", root.icon, "normal");
        }
    }

    // WhiteSur (icon-theme) symbolic battery icon for the current charge/state.
    readonly property string icon: {
        if (root.capacity < 0)
            return "battery-missing-symbolic";
        const lvl = Math.max(0, Math.min(100, Math.round(root.capacity / 10) * 10));
        // WhiteSur names the full+charging icon "-charged-", not "-charging-";
        // requesting the nonexistent name would fall back to a junk icon.
        if (root.status === "Charging")
            return lvl >= 100 ? "battery-level-100-charged-symbolic"
                              : "battery-level-" + lvl + "-charging-symbolic";
        return "battery-level-" + lvl + "-symbolic";
    }

    Process {
        id: batteryProc
        command: ["sh", "-c", "cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); st=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); echo \"$cap|$st\""]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split("|");
                const c = parseInt(parts[0]);
                root.capacity = isNaN(c) ? -1 : c;
                root.status = (parts[1] || "").trim();
                root.checkNotifications();
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: batteryProc.running = true
    }

    function init() {
    }
}
