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

qs ipc call screenshot show "$file" >/dev/null 2>&1 || true
