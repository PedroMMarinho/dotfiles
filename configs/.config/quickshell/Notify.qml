pragma Singleton

import QtQuick
import Quickshell

// Fire-and-forget desktop notifications, handed to whatever daemon owns
// org.freedesktop.Notifications (swaync here) so shell-generated popups look
// exactly like every other notification on the session.
//
// execDetached rather than a shared Process: two events landing in the same
// frame would otherwise race over the single command property.
Singleton {
    id: root

    // urgency: "low" | "normal" | "critical". Critical popups persist until
    // they are dismissed, so keep them for things that need acting on.
    function send(summary, body, icon, urgency) {
        const cmd = ["notify-send", "-a", "Shell"];

        if (icon)
            cmd.push("-i", icon);
        if (urgency)
            cmd.push("-u", urgency);

        cmd.push(summary);
        if (body)
            cmd.push(body);

        Quickshell.execDetached({ command: cmd });
    }
}
