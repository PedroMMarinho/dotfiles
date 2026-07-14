# macOS-Style Screenshot Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old grim/slurp `Screenshot.sh` bindings with a macOS-style capture tool: full-screen and area capture (with window hover-snap), shutter sound, clipboard copy, and a Quickshell floating thumbnail that opens swappy when clicked.

**Architecture:** A shell script (`screenshot.sh`) does the capture with grim/slurp, then fires `qs ipc call screenshot -- show <file>` at the already-running Quickshell instance. A new `screenshot/` Quickshell module (singleton `Controller.qml` + `Thumbnail.qml` window) renders the macOS-style thumbnail, following the exact pattern of the existing `power/` module. Two Hyprland keybinds invoke the script.

**Tech Stack:** bash, grim, slurp, jq, hyprctl, wl-copy, paplay/pw-play, Quickshell 0.3.0 (QML / QtQuick.Effects), swappy, hyprlua keybinds.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-macos-screenshot-tool-design.md`.
- Everything lives in `configs/.config/quickshell/screenshot/` (existing `configs` stow package — `~/.config/quickshell` is already a symlink into the repo, so files go live on save). Do NOT create a new top-level folder.
- Screenshot files: `~/Pictures/Screenshots/Screenshot YYYY-MM-DD at HH.MM.SS.png` (macOS naming, with spaces — quote every path).
- Keybinds: `SUPER+ALT+3` = full, `SUPER+ALT+4` = area. NOT `SUPER+SHIFT` — those numbers are taken by "move window to workspace N".
- IPC contract: `qs ipc call screenshot -- show <absolute-file-path>` (the `--` separator is required: Quickshell 0.3.0's CLI collides the function name `show` with the `qs ipc show` subcommand, silently rejecting the path argument otherwise).
- Capture must still succeed (file + clipboard) if sound playback or the Quickshell IPC call fails — those are best-effort.
- QML singletons here use `pragma Singleton` with plain directory imports and NO qmldir files — match the existing `power/Controller.qml` pattern exactly.
- Quickshell hot-reloads on file save. If it doesn't pick something up, restart with: `qs kill; (setsid qs >/dev/null 2>&1 &)`.
- This is compositor/desktop glue — no unit-test framework applies. Every task ends with exact manual verification commands run on the live Hyprland session, with expected observable results.
- All existing packages needed (grim, slurp, swappy, wl-clipboard, quickshell, jq) are already in `install.sh`'s PACKAGES list — no install.sh changes.
- Commit after each task with the trailer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Capture script + shutter sound

**Files:**
- Create: `configs/.config/quickshell/screenshot/screenshot.sh` (executable)
- Create: `configs/.config/quickshell/screenshot/shutter.oga` (copied from `/usr/share/sounds/freedesktop/stereo/camera-shutter.oga`, verified present, 23 KB)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `screenshot.sh full|area` — saves PNG to `~/Pictures/Screenshots/`, copies image to clipboard, plays shutter sound, then calls `qs ipc call screenshot -- show "<file>"` (best-effort; Task 2 implements the receiver). Exit 0 on success or user-cancel, 1 on bad usage/capture failure.

- [ ] **Step 1: Create the module folder and bundle the shutter sound**

```bash
mkdir -p /home/marinho/dotfiles/configs/.config/quickshell/screenshot
cp /usr/share/sounds/freedesktop/stereo/camera-shutter.oga \
   /home/marinho/dotfiles/configs/.config/quickshell/screenshot/shutter.oga
```

- [ ] **Step 2: Write the capture script**

Create `configs/.config/quickshell/screenshot/screenshot.sh`:

```bash
#!/usr/bin/env bash
# macOS-style screenshot: full-screen or area capture with window hover-snap.
# Saves with macOS naming, copies to the clipboard, plays a shutter sound and
# pops the Quickshell thumbnail preview. Sound and thumbnail are best-effort;
# the capture itself must not depend on them.

set -uo pipefail

mode="${1:-}"
dir="$HOME/Pictures/Screenshots"
self_dir="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
file="$dir/Screenshot $(date '+%Y-%m-%d at %H.%M.%S').png"

mkdir -p "$dir"

case "$mode" in
    full)
        grim "$file" || exit 1
        ;;
    area)
        # Visible windows on each monitor's active workspace become slurp
        # boxes: hovering snap-highlights a window, dragging still selects a
        # freehand region — both in one gesture (macOS Space-toggle analog).
        active_ws="$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')"
        boxes="$(hyprctl clients -j | jq -r --argjson ws "$active_ws" \
            '.[]
             | select(.mapped and (.hidden | not) and (.workspace.id as $id | $ws | index($id)))
             | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        geometry="$(printf '%s' "$boxes" | slurp)" || exit 0   # Escape cancels silently
        grim -g "$geometry" "$file" || exit 1
        ;;
    *)
        echo "usage: ${0##*/} full|area" >&2
        exit 1
        ;;
esac

wl-copy < "$file"

if command -v paplay >/dev/null 2>&1; then
    paplay "$self_dir/shutter.oga" &
elif command -v pw-play >/dev/null 2>&1; then
    pw-play "$self_dir/shutter.oga" &
fi

qs ipc call screenshot -- show "$file" >/dev/null 2>&1 || true
```

Then make it executable:

```bash
chmod +x /home/marinho/dotfiles/configs/.config/quickshell/screenshot/screenshot.sh
```

- [ ] **Step 3: Verify full-screen mode**

Run: `~/.config/quickshell/screenshot/screenshot.sh full && ls -t ~/Pictures/Screenshots | head -1 && wl-paste --list-types`

Expected: shutter sound plays; newest file is named like `Screenshot 2026-07-14 at 16.45.12.png`; `wl-paste --list-types` includes `image/png`. (The `qs ipc` call fails silently — the receiver doesn't exist until Task 2 — exit code must still be 0.)

- [ ] **Step 4: Verify area mode — drag, window snap, and cancel**

Run three times: `~/.config/quickshell/screenshot/screenshot.sh area; echo "exit=$?"`

1. Drag a freehand region → sound plays, new file contains that region, `exit=0`.
2. Hover a window (it highlights) and click it → new file is exactly that window, `exit=0`.
3. Press Escape → no sound, no new file in `~/Pictures/Screenshots`, `exit=0`.

- [ ] **Step 5: Verify bad usage**

Run: `~/.config/quickshell/screenshot/screenshot.sh; echo "exit=$?"`
Expected: `usage: screenshot.sh full|area` on stderr, `exit=1`, no file created.

- [ ] **Step 6: Commit**

```bash
cd /home/marinho/dotfiles
git add configs/.config/quickshell/screenshot/screenshot.sh configs/.config/quickshell/screenshot/shutter.oga
git commit -m "Add macOS-style screenshot capture script with shutter sound

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Quickshell thumbnail module

**Files:**
- Create: `configs/.config/quickshell/screenshot/Controller.qml`
- Create: `configs/.config/quickshell/screenshot/Thumbnail.qml`
- Modify: `configs/.config/quickshell/shell.qml` (add import + init call)

**Interfaces:**
- Consumes: `qs ipc call screenshot -- show <path>` from Task 1's script (also callable by hand for testing).
- Produces: IpcHandler target `screenshot` with `function show(path: string)`. Controller singleton API used by Thumbnail: `file` (string), `revealed` (bool), `hold()`, `release()`, `openEditor()`, `dismiss()`.

- [ ] **Step 1: Write the controller singleton**

Create `configs/.config/quickshell/screenshot/Controller.qml`:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Absolute path of the capture currently shown by the thumbnail.
    property string file: ""
    // isOpen keeps the window loaded; revealed drives the slide animation.
    // They differ only during the slide-out, so the exit animation can play
    // before the window unloads.
    property bool isOpen: false
    property bool revealed: false

    IpcHandler {
        target: "screenshot"

        function show(path: string): void {
            unloadTimer.stop();
            root.file = path;
            root.isOpen = true;
            root.revealed = true;
            dismissTimer.restart();
        }
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

    function init() {
    }
}
```

- [ ] **Step 2: Write the thumbnail window**

Create `configs/.config/quickshell/screenshot/Thumbnail.qml`:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var controller

    // Fixed width like macOS; height follows the capture's aspect ratio.
    readonly property int thumbWidth: 220
    readonly property int shadowPad: 24

    anchors {
        right: true
        bottom: true
    }
    margins {
        right: 12
        bottom: 12
    }

    implicitWidth: thumbWidth + shadowPad * 2
    implicitHeight: frame.height + shadowPad * 2

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:screenshot"

    Item {
        id: slide

        width: parent.width
        height: parent.height
        // Slide in from beyond the right edge, macOS style.
        x: root.controller.revealed ? 0 : root.implicitWidth + 16

        Behavior on x {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: frame

            x: root.shadowPad
            y: root.shadowPad
            width: root.thumbWidth
            height: img.status === Image.Ready && img.sourceSize.width > 0
                ? Math.min(Math.round(width * img.sourceSize.height / img.sourceSize.width), 220) + 8
                : 130
            radius: 10
            color: "#F2FFFFFF"          // white macOS-style frame
            border.color: "#33000000"
            border.width: 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#80000000"
                shadowBlur: 0.9
                shadowVerticalOffset: 4
            }

            Image {
                id: img

                anchors.fill: parent
                anchors.margins: 4
                source: root.controller.file !== "" ? "file://" + root.controller.file : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mask
                }
            }

            Item {
                id: mask

                anchors.fill: img
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "black"
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.controller.hold()
                onExited: root.controller.release()
                onClicked: root.controller.openEditor()
            }
        }
    }
}
```

- [ ] **Step 3: Wire the module into shell.qml**

Modify `configs/.config/quickshell/shell.qml` — the whole file becomes:

```qml
//@ pragma UseQApplication
import Quickshell
import QtQuick

import "launcher" as Launcher
import "bar" as Bar
import "power" as Power
import "lock" as Lock
import "screenshot" as Screenshot

ShellRoot {
        Bar.Bar {}
        Component.onCompleted: () => {
                Launcher.Controller.init();
                Power.Controller.init();
                Lock.Controller.init();
                Screenshot.Controller.init();
        }
}
```

- [ ] **Step 4: Reload Quickshell and verify the IPC target exists**

Quickshell hot-reloads on save; give it a second, then run: `qs ipc show`
Expected: output lists a `screenshot` target with `function show(path: string): void` alongside the existing `power` and `lock` targets.
If it's missing, restart: `qs kill; (setsid qs >/dev/null 2>&1 &)` and re-check. If it still fails, check `qs log` for QML errors.

- [ ] **Step 5: Verify thumbnail show / auto-dismiss / replace**

```bash
f="$(ls -t ~/Pictures/Screenshots/*.png | head -1)"
qs ipc call screenshot -- show "$f"
```

Expected: thumbnail slides in at the bottom-right showing that capture, with white frame, rounded corners, and drop shadow; after ~5 s it slides out and disappears.

Then fire it twice in a row with two different files:

```bash
files=($(ls -t ~/Pictures/Screenshots/*.png | head -2))
qs ipc call screenshot -- show "${files[1]}" && sleep 2 && qs ipc call screenshot -- show "${files[0]}"
```

Expected: the image swaps to the second file in place and the 5 s countdown restarts (no duplicate window).

- [ ] **Step 6: Verify hover-hold and click-to-annotate**

Run the single `show` command again. While the thumbnail is up: hover it for >5 s (it must NOT dismiss while hovered), then click it.
Expected: thumbnail slides out and swappy opens with the capture loaded; saving in swappy writes the annotated file.

- [ ] **Step 7: Verify the end-to-end script flow**

Run: `~/.config/quickshell/screenshot/screenshot.sh full`
Expected: sound plays AND the thumbnail now appears automatically (Task 1's IPC call has a live receiver).

- [ ] **Step 8: Commit**

```bash
cd /home/marinho/dotfiles
git add configs/.config/quickshell/screenshot/Controller.qml configs/.config/quickshell/screenshot/Thumbnail.qml configs/.config/quickshell/shell.qml
git commit -m "Add quickshell screenshot thumbnail module (macOS-style preview)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Hyprland keybinds

**Files:**
- Modify: `configs/.config/hypr/modules/variables.lua:41` (add screenshot script var)
- Modify: `configs/.config/hypr/modules/keybinds.lua:53-59` (replace the three old binds)

**Interfaces:**
- Consumes: `~/.config/quickshell/screenshot/screenshot.sh full|area` from Task 1.
- Produces: `v.screenshotScript` variable; `SUPER+ALT+3` / `SUPER+ALT+4` bindings.

- [ ] **Step 1: Add the script path variable**

In `configs/.config/hypr/modules/variables.lua`, after the line `v.scriptsDir = home .. "/.config/hypr/scripts"`, add:

```lua
v.screenshotScript = home .. "/.config/quickshell/screenshot/screenshot.sh"
```

- [ ] **Step 2: Replace the screenshot keybinds**

In `configs/.config/hypr/modules/keybinds.lua`, replace:

```lua
hl.bind(v.mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(v.scriptsDir .. "/Screenshot.sh --area"))
hl.bind(v.mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(v.scriptsDir .. "/Screenshot.sh --now"))
hl.bind(v.mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(v.scriptsDir .. "/Screenshot.sh --active"))
```

with:

```lua
-- macOS-style: SUPER+ALT because SUPER+SHIFT+[0-9] moves windows to workspaces
hl.bind(v.mainMod .. " + ALT + 3", hl.dsp.exec_cmd(v.screenshotScript .. " full"))
hl.bind(v.mainMod .. " + ALT + 4", hl.dsp.exec_cmd(v.screenshotScript .. " area"))
```

(Leave the old `scripts/Screenshot.sh` file in place — only the bindings move, per the spec.)

- [ ] **Step 3: Reload Hyprland config and verify no errors**

Run: `hyprctl reload && hyprctl binds | grep -A3 -i 'ALT' | grep -B1 -A2 screenshot`
Expected: `hyprctl reload` prints `ok`; the binds list shows the two screenshot.sh entries with SUPER+ALT modifiers, and `SUPER+SHIFT+S/O/W` no longer reference Screenshot.sh.

- [ ] **Step 4: Verify the keys end-to-end**

Press `SUPER+ALT+3`: shutter sound, thumbnail pops with a full-screen capture.
Press `SUPER+ALT+4`, drag a region: same for the region. Press `SUPER+ALT+4`, Escape: nothing happens.
Press `SUPER+SHIFT+3` with a window focused: the window still moves to workspace 3 (workspace binds untouched).

- [ ] **Step 5: Commit**

```bash
cd /home/marinho/dotfiles
git add configs/.config/hypr/modules/variables.lua configs/.config/hypr/modules/keybinds.lua
git commit -m "Bind macOS-style screenshot keys SUPER+ALT+3/4

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
