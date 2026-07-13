# macOS Lock Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS-style lock screen to the Quickshell desktop, triggered by `MOD + L`, with real PAM authentication over the secure `WlSessionLock` protocol.

**Architecture:** A new `lock/` Quickshell module mirroring the existing `power/` module. A `pragma Singleton` `Controller.qml` owns an `IpcHandler` (target `lock`), a `WlSessionLock`, and a `PamContext`. Setting `WlSessionLock.locked = true` makes the compositor lock the session and instantiate `Surface.qml` (a `WlSessionLockSurface`) on every monitor. The compositor enforces the lock, so a QML crash leaves the session locked, never unlocked.

**Tech Stack:** Quickshell 0.3.0 (QML), `Quickshell.Wayland` (WlSessionLock), `Quickshell.Services.Pam` (PamContext), `Quickshell.Io` (IpcHandler), Hyprland (keybind via Lua config).

## Global Constraints

- **Verification is a parse-gate + manual runtime.** A session-lock UI cannot be unit-tested; there is no headless harness. NOTE (execution deviation, 2026-07-11): `qmllint 1.0` crashes (exit 255, no output) on any file importing Quickshell's native modules — including known-good existing files — so it is NOT a usable gate in this environment. Substitute parse-gate: the live Quickshell instance (`~/.config/quickshell` is symlinked to this repo) hot-reloads on save; because `shell.qml` calls `Lock.Controller.init()`, the lock module is force-parsed on every reload WITHOUT setting `locked=true`. Gate each code step by: (a) `XDG_RUNTIME_DIR=/run/user/$(id -u) qs log 2>&1 | tail` shows `Configuration Loaded` with no lock-related ERROR, and (b) `qs ipc show` lists the expected `lock` target/functions. Then do the manual runtime check with the escape hatch below.
- **Dev safety escape hatch (MANDATORY before any lock test):** Open a second TTY with `Ctrl+Alt+F3` and log in *before* triggering a lock. To force-unlock from that TTY, run: `XDG_RUNTIME_DIR=/run/user/$(id -u) qs ipc call lock unlock`. Keep this TTY open during all of Tasks 1–2. `loginctl unlock-session` does **not** release a `WlSessionLock` and will not help.
- **Idiomatic Quickshell paths:** reference bundled assets with `root:/lock/...` (as `power/` does with `root:/power/icons/...`).
- **Singletons are directory-scoped:** within `lock/`, the type name `Controller` resolves to `lock/Controller.qml`; from `shell.qml` it is `Lock.Controller`. The existing root `Theme` singleton is referenced globally as `Theme` and its active palette is `Theme.get`.
- **Do not touch `hypridle.conf` or suspend config** — only `MOD + L` triggers this lock in this iteration.
- **PAM config:** use `config: "login"` (default directory `/etc/pam.d`). This authenticates the current user against their own password via the setuid `unix_chkpwd` helper — no root/file changes required.
- **Commit style:** end commit messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Work stays on branch `feat/quickshell-lock-screen`.

---

## File Structure

| Action | Path | Responsibility |
|---|---|---|
| Create | `configs/.config/quickshell/lock/Controller.qml` | Singleton: IPC entry, WlSessionLock state, PAM auth state machine |
| Create | `configs/.config/quickshell/lock/Surface.qml` | `WlSessionLockSurface`: the macOS visual UI, one per monitor |
| Create | `configs/.config/quickshell/lock/avatars/.gitkeep` | Placeholder dir; user drops `avatar.png` here later |
| Modify | `configs/.config/quickshell/shell.qml` | Register the lock Controller singleton |
| Modify | `configs/.config/hypr/modules/keybinds.lua` | Bind `MOD + L` to `qs ipc call lock lock` |

---

## Task 1: Session-lock plumbing (lock/unlock via IPC)

Get the risky compositor-level lock working with a trivial surface and a debug unlock, before adding PAM or visuals. This isolates lockout risk.

**Files:**
- Create: `configs/.config/quickshell/lock/Controller.qml`
- Create: `configs/.config/quickshell/lock/Surface.qml`
- Create: `configs/.config/quickshell/lock/avatars/.gitkeep`
- Modify: `configs/.config/quickshell/shell.qml`
- Modify: `configs/.config/hypr/modules/keybinds.lua`

**Interfaces:**
- Produces: `Controller` singleton (type `lock/Controller.qml`) exposing IPC `lock()` and `unlock()`; property `bool locked`. `Surface.qml` is a `WlSessionLockSurface` template consumed by `WlSessionLock`.

- [ ] **Step 1: Create the avatars placeholder directory**

Create the file `configs/.config/quickshell/lock/avatars/.gitkeep` with a single comment line:

```
# Place your macOS lock-screen avatar here as avatar.png
```

- [ ] **Step 2: Write the minimal Controller**

Create `configs/.config/quickshell/lock/Controller.qml`:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    // Drives the compositor-enforced session lock.
    property bool locked: false

    IpcHandler {
        target: "lock"

        function lock(): void { root.locked = true; }
        function unlock(): void { root.locked = false; } // debug escape hatch; removed in Task 3
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        // WlSessionLock's default property is `surface`; this template is
        // instantiated once per connected monitor by the compositor.
        Surface {}
    }

    function init() {}
}
```

- [ ] **Step 3: Write the minimal Surface**

Create `configs/.config/quickshell/lock/Surface.qml`:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

WlSessionLockSurface {
    id: surface
    color: "#1a1a1a"

    Text {
        anchors.centerIn: parent
        text: "Locked (Task 1 test surface)"
        color: "#ffffff"
        font.pixelSize: 24
    }
}
```

- [ ] **Step 4: Lint both files**

Run:
```bash
qmllint -I /usr/lib/qt6/qml configs/.config/quickshell/lock/Controller.qml configs/.config/quickshell/lock/Surface.qml
```
Expected: exit 0, no output.

- [ ] **Step 5: Register the Controller in shell.qml**

Modify `configs/.config/quickshell/shell.qml`. Add the import alongside the others and the init call alongside the others:

```qml
//@ pragma UseQApplication
import Quickshell
import QtQuick

import "launcher" as Launcher
import "bar" as Bar
import "power" as Power
import "lock" as Lock

ShellRoot {
        Bar.Bar {}
        Component.onCompleted: () => {
                Launcher.Controller.init();
                Power.Controller.init();
                Lock.Controller.init();
        }
}
```

- [ ] **Step 6: Bind MOD + L in Hyprland**

Modify `configs/.config/hypr/modules/keybinds.lua`. Replace the commented line 48:

```lua
-- hl.bind(v.mainMod .. " + L", hl.dsp.exec_cmd(v.scriptsDir .. "/LockScreen.sh"))
```

with:

```lua
hl.bind(v.mainMod .. " + L", hl.dsp.exec_cmd("qs ipc call lock lock"))
```

- [ ] **Step 7: Manual runtime verification (with escape hatch ready)**

First open `Ctrl+Alt+F3`, log in, and keep it ready. Back in the graphical session, reload Quickshell so it picks up the new module (Quickshell hot-reloads on file save; if not running, start it). Then:

```bash
qs ipc call lock lock
```
Expected: every monitor shows a dark screen with "Locked (Task 1 test surface)". Keyboard/mouse do not reach the desktop.

From the graphical session's reachable terminal (or the F3 TTY), unlock:
```bash
qs ipc call lock unlock
```
Expected: the desktop returns cleanly on all monitors. Also confirm `MOD + L` produces the same lock.

- [ ] **Step 8: Commit**

```bash
git add configs/.config/quickshell/lock/ configs/.config/quickshell/shell.qml configs/.config/hypr/modules/keybinds.lua
git commit -m "$(cat <<'EOF'
feat(lock): add Quickshell session-lock plumbing bound to MOD+L

New lock/ module with a WlSessionLock driven by an IpcHandler (target
"lock"). MOD+L calls `qs ipc call lock lock`. Trivial placeholder surface
and a debug unlock IPC; PAM auth and macOS visuals follow.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: PAM authentication

Replace the debug unlock with real password authentication. Surface gets a bare password input; visuals come in Task 3.

**Files:**
- Modify: `configs/.config/quickshell/lock/Controller.qml`
- Modify: `configs/.config/quickshell/lock/Surface.qml`

**Interfaces:**
- Consumes: `Controller` singleton and its `locked` property from Task 1.
- Produces: `Controller.submit(password: string)` — starts PAM auth, unlocks on success; `Controller` properties `bool authenticating`, `bool failed`, `string statusText`; signal `failedPulse()` emitted on a failed/errored attempt.

- [ ] **Step 1: Add PAM state and logic to the Controller**

Modify `configs/.config/quickshell/lock/Controller.qml` to the following complete content:

```qml
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
```

- [ ] **Step 2: Add a bare password input to the Surface**

Modify `configs/.config/quickshell/lock/Surface.qml` to the following complete content:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

WlSessionLockSurface {
    id: surface
    color: "#1a1a1a"

    Column {
        anchors.centerIn: parent
        spacing: 16

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Controller.statusText
            color: Controller.failed ? "#ff6b6b" : "#ffffff"
            font.pixelSize: 18
        }

        Rectangle {
            width: 260
            height: 44
            radius: 22
            color: "#33ffffff"
            border.color: "#66ffffff"

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: "#ffffff"
                clip: true
                enabled: !Controller.authenticating
                onAccepted: Controller.submit(text)
            }
        }
    }

    // Grab keyboard focus when this surface appears.
    Component.onCompleted: pw.forceActiveFocus()

    // Clear + refocus + reset on a failed attempt.
    Connections {
        target: Controller
        function onFailedPulse() {
            pw.text = "";
            pw.forceActiveFocus();
        }
    }
}
```

- [ ] **Step 3: Lint both files**

Run:
```bash
qmllint -I /usr/lib/qt6/qml configs/.config/quickshell/lock/Controller.qml configs/.config/quickshell/lock/Surface.qml
```
Expected: exit 0, no output.

- [ ] **Step 4: Manual runtime verification (escape hatch ready)**

With the `Ctrl+Alt+F3` TTY logged in and ready, reload Quickshell, then `qs ipc call lock lock`.
- Type a **wrong** password + Enter → status turns red "Incorrect password. Try again.", field clears, stays locked.
- Type your **correct** password + Enter → session unlocks cleanly on all monitors.
- If anything hangs, force-unlock from the F3 TTY: `XDG_RUNTIME_DIR=/run/user/$(id -u) qs ipc call lock unlock`.

- [ ] **Step 5: Commit**

```bash
git add configs/.config/quickshell/lock/Controller.qml configs/.config/quickshell/lock/Surface.qml
git commit -m "$(cat <<'EOF'
feat(lock): authenticate the session lock with PAM

Controller runs a PamContext (config "login") on submit, unlocking on
PamResult.Success and shaking/clearing on failure. Surface gains a bare
password field wired to Controller.submit().

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: macOS visual design

Redesign the Surface into the macOS lock screen: blurred wallpaper, clock, avatar, name, styled password pill with shake, theme colors. Remove the debug unlock IPC.

**Files:**
- Modify: `configs/.config/quickshell/lock/Surface.qml`
- Modify: `configs/.config/quickshell/lock/Controller.qml`

**Interfaces:**
- Consumes: all `Controller` members from Task 2 (`submit`, `authenticating`, `failed`, `statusText`, `failedPulse`, `locked`).

- [ ] **Step 1: Remove the debug unlock IPC from the Controller**

In `configs/.config/quickshell/lock/Controller.qml`, delete the debug `unlock` function line inside the `IpcHandler` so it reads:

```qml
    IpcHandler {
        target: "lock"

        function lock(): void { root.locked = true; }
    }
```

Leave the rest of the Controller unchanged.

- [ ] **Step 2: Rewrite the Surface with the macOS UI**

Replace `configs/.config/quickshell/lock/Surface.qml` with the following complete content:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

WlSessionLockSurface {
    id: surface
    color: "#000000"

    // --- Tunables ------------------------------------------------------
    readonly property string wallpaperSource: "file://" + Quickshell.env("HOME")
        + "/.config/hypr/wallpaper_effects/current_wallpaper"
    property string displayName: Quickshell.env("USER")
    // -------------------------------------------------------------------

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Solid fallback background (shown if the wallpaper file is missing).
    Rectangle {
        anchors.fill: parent
        color: "#0d1b2a"
    }

    // Blurred wallpaper.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: surface.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
        asynchronous: true
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.25
    }

    // Dark scrim for legibility.
    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    // Clock + date, upper third.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.14
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "#ffffff"
            font.family: "Adwaita Sans"
            font.pixelSize: Math.round(surface.height * 0.13)
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: "#e0ffffff"
            font.family: "Adwaita Sans"
            font.pixelSize: Math.round(surface.height * 0.028)
        }
    }

    // Avatar + name + password pill, lower-center.
    Column {
        id: authColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.16
        spacing: 14

        // Circular avatar with glyph fallback.
        Rectangle {
            id: avatarRing
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(surface.height * 0.11)
            height: width
            radius: width / 2
            color: "#33ffffff"
            border.color: "#88ffffff"
            border.width: 2
            clip: true

            Image {
                id: avatarImg
                anchors.fill: parent
                anchors.margins: 2
                source: "root:/lock/avatars/avatar.png"
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                asynchronous: true
                cache: false
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: avatarMask }
            }

            // Circular mask for the avatar image.
            Item {
                id: avatarMask
                anchors.fill: parent
                anchors.margins: 2
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#ffffff"
                }
            }

            // Fallback glyph (Nerd Font person) when no avatar image exists.
            Text {
                anchors.centerIn: parent
                visible: avatarImg.status !== Image.Ready
                text: "" // nf-fa-user
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: parent.height * 0.5
                color: "#ffffff"
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: surface.displayName
            color: "#ffffff"
            font.family: "Adwaita Sans"
            font.pixelSize: Math.round(surface.height * 0.026)
            font.bold: true
        }

        // Password pill (shakes on failure).
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(surface.width * 0.16)
            height: Math.round(surface.height * 0.045)
            radius: height / 2
            color: Controller.failed ? "#40ff5555" : "#33ffffff"
            border.color: Controller.failed ? "#ccff5555" : "#66ffffff"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: pill.height * 0.6
                anchors.verticalCenter: parent.verticalCenter
                visible: pw.text.length === 0
                text: Controller.statusText
                color: Controller.failed ? "#ffd0d0" : "#b0ffffff"
                font.family: "Adwaita Sans"
                font.pixelSize: pill.height * 0.34
            }

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: pill.height * 0.6
                anchors.rightMargin: pill.height * 1.4
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: "#ffffff"
                clip: true
                font.family: "Adwaita Sans"
                font.pixelSize: pill.height * 0.4
                enabled: !Controller.authenticating
                onAccepted: Controller.submit(text)
            }

            // Submit affordance.
            Text {
                anchors.right: parent.right
                anchors.rightMargin: pill.height * 0.5
                anchors.verticalCenter: parent.verticalCenter
                visible: pw.text.length > 0 && !Controller.authenticating
                text: "›"
                // Theme accent (whiteSur_dark), ties the lock into the shared palette.
                color: Theme.get.wlogoutSelectedBorder
                font.pixelSize: pill.height * 0.6
                MouseArea {
                    anchors.fill: parent
                    onClicked: Controller.submit(pw.text)
                }
            }

            // Horizontal shake on a failed attempt.
            SequentialAnimation {
                id: shake
                loops: 1
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 12; duration: 40 }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -12; duration: 80 }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 8; duration: 60 }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
            }
        }
    }

    Component.onCompleted: pw.forceActiveFocus()

    Connections {
        target: Controller
        function onFailedPulse() {
            pw.text = "";
            pw.forceActiveFocus();
            shake.restart();
        }
    }
}
```

- [ ] **Step 3: Lint both files**

Run:
```bash
qmllint -I /usr/lib/qt6/qml configs/.config/quickshell/lock/Controller.qml configs/.config/quickshell/lock/Surface.qml
```
Expected: exit 0, no output. (If `qmllint` warns about `anchors.horizontalCenterOffset` as an animation target, that is a known false positive for grouped-property animation and can be ignored; the runtime check below is authoritative.)

- [ ] **Step 4: Full manual verification (escape hatch ready)**

Because the debug `unlock` IPC is now removed, the ONLY unlock paths are a correct password and `Ctrl+Alt+F3` → kill/reload Quickshell. Have the F3 TTY logged in first. Reload Quickshell, then `qs ipc call lock lock` and confirm the checklist from the spec:

1. Lock fires; blurred wallpaper (or solid `#0d1b2a` fallback) renders on all monitors.
2. Clock shows `HH:mm` and updates; date line shows weekday + month/day.
3. Avatar ring shows the Nerd Font person glyph (no image yet); name shows your username.
4. Wrong password → pill shakes, turns red, clears; stays locked.
5. Correct password → clean unlock on all monitors.
6. No bypass: `Esc`, clicking around, and workspace-switch keys do nothing.
7. `MOD + L` triggers the same lock.

- [ ] **Step 5: Commit**

```bash
git add configs/.config/quickshell/lock/Controller.qml configs/.config/quickshell/lock/Surface.qml
git commit -m "$(cat <<'EOF'
feat(lock): macOS-style lock screen visuals

Blurred wallpaper background, large clock + date, circular avatar with
Nerd Font fallback, username, and a rounded password pill with shake-on-
failure. Removes the debug unlock IPC now that PAM auth is the entry path.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Post-implementation notes

- **Avatar:** drop a square image at `configs/.config/quickshell/lock/avatars/avatar.png`. The ring auto-switches from the glyph to the masked image.
- **Full name instead of username:** change `property string displayName` in `Surface.qml` to a literal (e.g. `"Pedro Marinho"`).
- **If PAM rejects the correct password** at runtime: the `config: "login"` PAM stack may pull in a module that fails for a non-login context on this system. Fallback — create `configs/.config/quickshell/lock/pam.d/quickshell` containing `auth include system-auth`, then set on the `PamContext`: `configDirectory: Quickshell.env("HOME") + "/.config/quickshell/lock/pam.d"` and `config: "quickshell"`. Re-verify.
- **Deferred (future iteration):** wire idle-timeout and before-suspend to `qs ipc call lock lock` in `hypridle.conf`, replacing the dead `hyprlock` references.
