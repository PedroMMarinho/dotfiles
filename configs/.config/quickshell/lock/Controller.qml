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

    // Auth state, shared across all per-monitor surfaces.
    property bool authenticating: false
    property bool failed: false
    property string statusText: "Enter Password"

    // Internal buffer of the password currently being verified.
    property string _pending: ""

    // Emitted on a failed/errored attempt so surfaces can shake + clear.
    signal failedPulse()

    IpcHandler {
        target: "lock"

        function lock(): void { root.locked = true; }
        function unlock(): void { root.locked = false; } // debug escape hatch; removed in Task 3
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
                root.statusText = "Enter Password";
                root.locked = false;
            } else {
                root.failed = true;
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
            root.statusText = "Authentication error.";
            root.failedPulse();
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        Surface {}
    }

    function init() {}
}
