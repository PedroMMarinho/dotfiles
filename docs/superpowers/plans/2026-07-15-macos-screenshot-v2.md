# macOS-Style Screenshot Tool v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix v1's capture-quality bugs (border ring, baked-in cursor, thumbnail-in-screenshot, fullscreen occlusion) and rework it into three modes (full/window/crop) with a draggable, macOS-dark thumbnail popup and a camera cursor during window picking.

**Architecture:** Same three-layer shape as v1 — a bash capture script (`screenshot.sh`), a Quickshell singleton + layer-shell popup (`Controller.qml`/`Thumbnail.qml`), and hyprlua keybinds. v2 adds a generated Xcursor theme as a stow-managed asset and an instant-`hide` IPC path from the script to the popup.

**Tech Stack:** bash, grim, slurp, jq, hyprctl, wl-clipboard, Quickshell 0.3.0 (QML), ImageMagick + xcursorgen (asset build only), GNU stow.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-15-macos-screenshot-v2-design.md` (supersedes the v1 spec's mode split).
- Screenshot files: `~/Pictures/Screenshots/Screenshot YYYY-MM-DD at HH.MM.SS.png` (spaces — quote every path).
- Keybinds: `SUPER+ALT+3` = full, `SUPER+ALT+4` = window, `SUPER+SHIFT+S` = crop. The v1 `area` mode is removed, not aliased.
- IPC contract: `qs ipc call screenshot -- show <absolute-file-path>` and `qs ipc call screenshot -- hide` (the `--` separator is required on Quickshell 0.3.0; without it the CLI collides function names with its own subcommands and silently rejects arguments).
- Capture (file + clipboard) must still succeed if sound, popup IPC, or cursor cosmetics fail — those are best-effort.
- Every temporary system tweak (cursor:no_hardware_cursors, cursor theme) is restored by an EXIT trap, including on cancel (slurp Escape) and failure paths.
- QML singletons use `pragma Singleton` with plain directory imports and NO qmldir files — match the existing `screenshot/Controller.qml` pattern.
- Quickshell hot-reloads on file save. If it doesn't pick something up: `qs kill; (setsid qs >/dev/null 2>&1 &)`.
- Compositor/desktop glue — no unit-test framework. Every task ends with exact manual verification commands on the live Hyprland session with expected observable results.
- The user's cursor theme is `macOS`, size 24 (set in `configs/.config/hypr/modules/env.lua`); the camera theme must inherit it.
- Live-session facts (probed 2026-07-15): `general:border_size` = 1; `hyprctl clients -j` `.fullscreen` is an int (0 none, 1 maximized, 2 fullscreen); maximized windows report their true geometry AND keep their border; fullscreen(2) windows are borderless; `cursor:no_hardware_cursors` currently 2 (auto). Do not hardcode these — read them at runtime where the code needs them.
- `git status` shows a pre-existing unrelated modification to `configs/.config/fcitx5/profile` — never stage or commit it.
- Commit after each task with the trailer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Camera cursor theme asset

**Files:**
- Create: `cursor/.icons/screenshot-camera/index.theme`
- Create: `cursor/.icons/screenshot-camera/cursors/camera` (xcursor binary)
- Create: `cursor/.icons/screenshot-camera/cursors/{left_ptr,default,crosshair,cross}` (symlinks to `camera`)

**Interfaces:**
- Consumes: nothing from other tasks. Requires `xcursorgen` (package `xorg-xcursorgen`) and `magick` on PATH.
- Produces: an installed cursor theme named `screenshot-camera` resolvable by `hyprctl setcursor screenshot-camera 24` (used verbatim by Task 3).

- [ ] **Step 1: Check prerequisites**

Run: `command -v xcursorgen magick stow`
Expected: three paths printed. If `xcursorgen` is missing, STOP and report BLOCKED — the controller must have the user run `sudo pacman -S --needed xorg-xcursorgen`. Do not attempt sudo yourself.

- [ ] **Step 2: Render the camera glyph PNGs**

macOS-style: dark camera glyph on a white rounded square (per user request). Work in a scratch dir:

```bash
work="$(mktemp -d)"
cd "$work"
# 48px master: white rounded square, faint outline, dark camera
# (viewfinder bump, body, lens ring cut out of the body, dark pupil).
magick -size 48x48 xc:none \
  -fill 'rgba(255,255,255,0.96)' -stroke 'rgba(0,0,0,0.30)' -strokewidth 1 \
  -draw 'roundrectangle 2,2 45,45 11,11' \
  -stroke none \
  -fill '#2A2A2A' -draw 'roundrectangle 17,12 31,20 3,3' \
  -fill '#2A2A2A' -draw 'roundrectangle 9,16 39,37 4,4' \
  -fill 'rgba(255,255,255,0.96)' -draw 'circle 24,26.5 24,33' \
  -fill '#2A2A2A' -draw 'circle 24,26.5 24,31' \
  camera-48.png
magick camera-48.png -resize 24x24 camera-24.png
```

Expected: `camera-48.png` and `camera-24.png` exist. Sanity-check with `magick identify camera-*.png` (48x48 and 24x24, 8-bit sRGBA).

- [ ] **Step 3: Build the xcursor file (hotspot = center)**

```bash
cat > camera.cfg <<'EOF'
24 12 12 camera-24.png
48 24 24 camera-48.png
EOF
xcursorgen camera.cfg camera
```

Expected: file `camera` created; `file camera` reports "X11 cursor".

- [ ] **Step 4: Lay out the theme in the repo's `cursor` stow package**

```bash
theme_dir=/home/marinho/dotfiles/cursor/.icons/screenshot-camera
mkdir -p "$theme_dir/cursors"
cp camera "$theme_dir/cursors/camera"
cat > "$theme_dir/index.theme" <<'EOF'
[Icon Theme]
Name=screenshot-camera
Inherits=macOS
EOF
cd "$theme_dir/cursors"
for alias in left_ptr default crosshair cross; do ln -sf camera "$alias"; done
```

Expected: `ls -l "$theme_dir/cursors"` shows `camera` plus 4 relative symlinks to it.

- [ ] **Step 5: Restow the cursor package and verify the theme resolves**

```bash
cd /home/marinho/dotfiles && stow -R -t "$HOME" cursor
command ls -l "$HOME/.icons/screenshot-camera"
hyprctl setcursor screenshot-camera 24
hyprctl setcursor macOS 24
```

Expected: `~/.icons/screenshot-camera` exists (via stow symlink); both `hyprctl setcursor` calls print `ok`. The second call restores the user's normal cursor — never leave the camera theme active.

- [ ] **Step 6: Commit**

```bash
cd /home/marinho/dotfiles
git add cursor/.icons/screenshot-camera
git commit -m "Add screenshot-camera cursor theme (macOS-style camera glyph)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Thumbnail popup v2 — instant hide IPC, drag-to-reposition, macOS dark frame

**Files:**
- Modify: `configs/.config/quickshell/screenshot/Controller.qml`
- Modify: `configs/.config/quickshell/screenshot/Thumbnail.qml`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: IPC `qs ipc call screenshot -- hide` (instant hide, used by Task 3); controller properties `posRight: int` / `posBottom: int` (popup position as layer margins, reset to 12/12 by `show`); existing `show(path)`, `hold()`, `release()`, `openEditor()` unchanged in signature.

- [ ] **Step 1: Replace `Controller.qml` with the v2 version**

Full new file content:

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
    // Popup position, expressed as layer-surface margins. Dragging in
    // Thumbnail.qml writes these; every new capture resets to bottom-right.
    property int posRight: 12
    property int posBottom: 12

    IpcHandler {
        target: "screenshot"

        function show(path: string): void {
            unloadTimer.stop();
            root.file = path;
            root.posRight = 12;
            root.posBottom = 12;
            root.isOpen = true;
            root.revealed = true;
            dismissTimer.restart();
        }

        // Instant hide, no slide-out: screenshot.sh calls this right before
        // capturing so a previous thumbnail is never in the new screenshot.
        function hide(): void {
            dismissTimer.stop();
            unloadTimer.stop();
            root.revealed = false;
            root.isOpen = false;
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

- [ ] **Step 2: Replace `Thumbnail.qml` with the v2 version**

Full new file content:

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
    // Position comes from the controller so dragging survives image swaps
    // and show() can reset it to the corner.
    margins {
        right: root.controller.posRight
        bottom: root.controller.posBottom
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
            color: "#F22A2A2A"          // macOS dark charcoal frame
            border.color: "#40FFFFFF"   // subtle light hairline
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
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                // Press-and-move beyond the threshold drags the popup by
                // adjusting the layer margins (Hyprland never moves the
                // surface itself, so there is nothing to jitter). A release
                // below the threshold is a click and opens the editor.
                property real pressX: 0
                property real pressY: 0
                property bool dragging: false

                onEntered: root.controller.hold()
                onExited: root.controller.release()

                onPressed: (event) => {
                    pressX = event.x;
                    pressY = event.y;
                    dragging = false;
                    root.controller.hold();
                }

                onPositionChanged: (event) => {
                    if (!pressed)
                        return;
                    const dx = event.x - pressX;
                    const dy = event.y - pressY;
                    if (!dragging && Math.abs(dx) < 6 && Math.abs(dy) < 6)
                        return;
                    dragging = true;
                    const maxRight = root.screen.width - root.implicitWidth;
                    const maxBottom = root.screen.height - root.implicitHeight;
                    root.controller.posRight = Math.max(0, Math.min(root.controller.posRight - dx, maxRight));
                    root.controller.posBottom = Math.max(0, Math.min(root.controller.posBottom - dy, maxBottom));
                }

                onReleased: {
                    if (!dragging)
                        root.controller.openEditor();
                    else if (!containsMouse)
                        root.controller.release();
                }
            }
        }
    }
}
```

Note this replaces the v1 `onClicked` handler: click is now "released without dragging".

- [ ] **Step 3: Verify Quickshell reloaded without errors**

Run: `qs log 2>/dev/null | tail -20` (or check `journalctl --user -u quickshell` equivalent; if neither exists, restart with `qs kill; (setsid qs >/dev/null 2>&1 &)` and wait 2s).
Then: `qs ipc show | grep -A4 'target screenshot'`
Expected: both `function show(path: string): void` and `function hide(): void` listed. No QML errors mentioning `screenshot/` files in the log.

- [ ] **Step 4: Verify show → hide → show over IPC**

```bash
f="$(command ls -t "$HOME/Pictures/Screenshots/"*.png | head -1)"
qs ipc call screenshot -- show "$f"; sleep 0.5
hyprctl layers | grep -c 'shell:screenshot'   # expect >= 1
qs ipc call screenshot -- hide; sleep 0.5
hyprctl layers | grep -c 'shell:screenshot'   # expect 0
qs ipc call screenshot -- show "$f"; sleep 6
hyprctl layers | grep -c 'shell:screenshot'   # expect 0 (auto-dismiss still works)
```

Expected: counts 1 (or more), then 0, then 0. (grep exits 1 when the count is 0 — that is the expected "0" case, not a failure.)

Drag, hover-hold, and click-opens-swappy need a human pointer — defer to the final user verification; note the deferral in your report.

- [ ] **Step 5: Commit**

```bash
cd /home/marinho/dotfiles
git add configs/.config/quickshell/screenshot/Controller.qml configs/.config/quickshell/screenshot/Thumbnail.qml
git commit -m "Thumbnail popup v2: instant hide IPC, drag-to-reposition, macOS dark frame

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: screenshot.sh v2 — full/window/crop modes with capture hygiene

**Files:**
- Modify: `configs/.config/quickshell/screenshot/screenshot.sh` (full rewrite)

**Interfaces:**
- Consumes: `qs ipc call screenshot -- hide` from Task 2; cursor theme `screenshot-camera` from Task 1.
- Produces: `screenshot.sh full|window|crop` CLI (used by Task 4's keybinds). `area` no longer accepted.

- [ ] **Step 1: Replace the script**

Full new file content:

```bash
#!/usr/bin/env bash
# macOS-style screenshot: full-screen, window-pick, or freehand crop.
# Saves with macOS naming, copies to the clipboard, plays a shutter sound and
# pops the Quickshell thumbnail preview. Sound, popup and cursor cosmetics
# are best-effort; the capture itself must not depend on them.

set -uo pipefail

mode="${1:-}"
dir="$HOME/Pictures/Screenshots"
self_dir="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
file="$dir/Screenshot $(date '+%Y-%m-%d at %H.%M.%S').png"

mkdir -p "$dir"

# --- capture hygiene --------------------------------------------------------
# A previous thumbnail must never appear inside a new capture.
qs ipc call screenshot -- hide >/dev/null 2>&1 || true

# NVIDIA hardware cursors get composited into screencopy frames, baking the
# pointer into screenshots. Disable them for the duration of the capture and
# restore the previous value on ANY exit (including slurp Escape).
hw_prev="$(hyprctl getoption cursor:no_hardware_cursors -j 2>/dev/null | jq -r '.int' 2>/dev/null || true)"
[ "$hw_prev" = "null" ] && hw_prev=""
cursor_swapped=0
restore() {
    if [ -n "$hw_prev" ]; then
        hyprctl keyword cursor:no_hardware_cursors "$hw_prev" >/dev/null 2>&1
    fi
    if [ "$cursor_swapped" = 1 ]; then
        hyprctl setcursor "${XCURSOR_THEME:-macOS}" "${XCURSOR_SIZE:-24}" >/dev/null 2>&1
    fi
}
trap restore EXIT
if [ -n "$hw_prev" ]; then
    hyprctl keyword cursor:no_hardware_cursors 1 >/dev/null 2>&1
fi

window_boxes() {
    # Visible windows on each monitor's active workspace become slurp boxes,
    # shrunk by the border size so Hyprland's border ring stays out of the
    # capture. If a workspace has a fullscreen/maximized window, only it is
    # offered — windows underneath would give half-covered captures. True
    # fullscreen (2) windows are borderless, so they are not shrunk.
    local ws bs
    ws="$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')"
    bs="$(hyprctl getoption general:border_size -j | jq '.int')"
    hyprctl clients -j | jq -r --argjson ws "$ws" --argjson bs "$bs" '
        [ .[] | select(.mapped and (.hidden | not)
                       and (.workspace.id as $id | $ws | index($id))) ]
        | group_by(.workspace.id)
        | map(if any(.fullscreen != 0) then map(select(.fullscreen != 0)) else . end)
        | flatten
        | .[]
        | (if .fullscreen == 2 then 0 else $bs end) as $b
        | "\(.at[0]+$b),\(.at[1]+$b) \(.size[0]-2*$b)x\(.size[1]-2*$b)"'
}

case "$mode" in
    full)
        grim "$file" || exit 1
        ;;
    window)
        # Camera pointer while picking; restore handled by the EXIT trap.
        if hyprctl setcursor screenshot-camera "${XCURSOR_SIZE:-24}" >/dev/null 2>&1; then
            cursor_swapped=1
        fi
        geometry="$(window_boxes | slurp -r -b '#00000066' -c '#FFFFFFFF' -w 2 -s '#FFFFFF22')" || exit 0
        grim -g "$geometry" "$file" || exit 1
        ;;
    crop)
        geometry="$(slurp -b '#00000066' -c '#FFFFFFFF' -w 2)" || exit 0   # Escape cancels silently
        grim -g "$geometry" "$file" || exit 1
        ;;
    *)
        echo "usage: ${0##*/} full|window|crop" >&2
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

- [ ] **Step 2: Syntax check and usage error**

```bash
bash -n ~/.config/quickshell/screenshot/screenshot.sh && echo SYNTAX_OK
~/.config/quickshell/screenshot/screenshot.sh; echo "exit=$?"
~/.config/quickshell/screenshot/screenshot.sh area; echo "exit=$?"
```

Expected: `SYNTAX_OK`; both invalid invocations print `usage: screenshot.sh full|window|crop` and `exit=1`. (`area` must be rejected — it was removed.)

- [ ] **Step 3: Verify window_boxes output shape**

Run the function body standalone (paste into a shell) or temporarily: `bash -c 'source /dev/stdin <<< "$(sed -n "/^window_boxes()/,/^}/p" ~/.config/quickshell/screenshot/screenshot.sh)"; window_boxes'`
Expected: one `X,Y WxH` line per visible window; with border_size=1, values are shifted by +1/+1 and shrunk by 2 versus `hyprctl clients -j` for non-fullscreen windows. If a workspace has a fullscreen/maximized window, only that window's line appears for it.

- [ ] **Step 4: End-to-end full capture**

```bash
before="$(hyprctl getoption cursor:no_hardware_cursors -j | jq '.int')"
~/.config/quickshell/screenshot/screenshot.sh full; echo "exit=$?"
command ls -t "$HOME/Pictures/Screenshots" | head -1
wl-paste --list-types
after="$(hyprctl getoption cursor:no_hardware_cursors -j | jq '.int')"
echo "hw_cursor: before=$before after=$after"
```

Expected: `exit=0`; a new file with the current timestamp; `image/png` in the clipboard types; `before` == `after` (setting restored). The thumbnail layer should appear (`hyprctl layers | grep shell:screenshot`).

- [ ] **Step 5: Verify trap restores on cancel (no display interaction needed)**

`window` and `crop` need a pointer; what CAN be verified headlessly is the cancel path: run `timeout 2 ~/.config/quickshell/screenshot/screenshot.sh crop; echo "exit=$?"` (timeout kills slurp, same code path as a cancel — expect nonzero exit from timeout itself, that's fine) and then confirm `hyprctl getoption cursor:no_hardware_cursors -j | jq '.int'` equals the pre-run value and `hyprctl getoption` for the cursor theme was never left as `screenshot-camera` (`hyprctl setcursor macOS 24` should NOT be needed — but run `echo "$XCURSOR_THEME"` and visually confirm the pointer is normal). Note interactive window/crop capture verification as deferred to the final user verification in your report.

- [ ] **Step 6: Commit**

```bash
cd /home/marinho/dotfiles
git add configs/.config/quickshell/screenshot/screenshot.sh
git commit -m "screenshot.sh v2: full/window/crop modes with capture hygiene

Border-free window boxes, fullscreen occlusion filter, hardware-cursor
toggle during capture, instant thumbnail hide, camera cursor in window mode.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Keybinds and lint housekeeping

**Files:**
- Modify: `configs/.config/hypr/modules/keybinds.lua` (screenshot block, currently lines 53-60; plus trailing-space fixes at lines 46 and 60)

**Interfaces:**
- Consumes: `screenshot.sh full|window|crop` from Task 3; `v.screenshotScript` variable (already exists in `variables.lua` from v1).
- Produces: final keybinds `SUPER+ALT+3`/`SUPER+ALT+4`/`SUPER+SHIFT+S`.

- [ ] **Step 1: Update the screenshot binds**

Replace:

```lua
-- macOS-style: SUPER+ALT because SUPER+SHIFT+[0-9] moves windows to workspaces
hl.bind(v.mainMod .. " + ALT + 3", hl.dsp.exec_cmd(v.screenshotScript .. " full"))
hl.bind(v.mainMod .. " + ALT + 4", hl.dsp.exec_cmd(v.screenshotScript .. " area"))
```

with:

```lua
-- macOS-style: SUPER+ALT because SUPER+SHIFT+[0-9] moves windows to workspaces
hl.bind(v.mainMod .. " + ALT + 3", hl.dsp.exec_cmd(v.screenshotScript .. " full"))
hl.bind(v.mainMod .. " + ALT + 4", hl.dsp.exec_cmd(v.screenshotScript .. " window"))
hl.bind(v.mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(v.screenshotScript .. " crop"))
```

- [ ] **Step 2: Fix the two lint warnings in the same file**

Line 46 ends with two trailing spaces after `.../Keyboard.sh"))` — delete them. The line after the ALT+4 bind (was line 60) contains only spaces — make it empty. Change nothing else on those lines.

- [ ] **Step 3: Reload and verify**

```bash
hyprctl reload
hyprctl binds | awk '/modmask/ {print}' | sort | uniq -c | head
```

Expected: `hyprctl reload` prints `ok`. Because Lua-mode binds expose only `dispatcher: __lua`, verify by modmask instead: `hyprctl binds` must contain entries with modmask 72 (SUPER+ALT) for keys 3 and 4, and modmask 65 (SUPER+SHIFT) for key S. Confirm no bind with modmask 65 + key S existed before this change (`git stash` not needed — v1 removed the old SUPER+SHIFT+S bind; if a conflict appears, STOP and report BLOCKED).

- [ ] **Step 4: Commit**

```bash
cd /home/marinho/dotfiles
git add configs/.config/hypr/modules/keybinds.lua
git commit -m "Rebind screenshots: ALT+4 window-pick, SHIFT+S crop; strip trailing whitespace

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Final verification (human, live session)

Run the 10-point checklist from the spec (`docs/superpowers/specs/2026-07-15-macos-screenshot-v2-design.md`, Testing section): border-free/cursor-free/popup-free captures, fullscreen filter, camera cursor + restore on Escape, `slurp -r` no-drag behavior in window mode, crop mode, popup drag/click/hover, dark frame, hw-cursor option restored, workspace binds intact.
