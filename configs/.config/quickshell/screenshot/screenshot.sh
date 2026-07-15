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
tmp_file=""
restore() {
    [ -n "$tmp_file" ] && rm -f "$tmp_file"
    if [ -n "$hw_prev" ]; then
        hyprctl keyword cursor:no_hardware_cursors "$hw_prev" >/dev/null 2>&1
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
        # Freeze-then-crop: capture the whole layout BEFORE slurp draws, then
        # cut the picked region out of that frame. Nothing slurp renders (dim,
        # selection border, pointer) can leak into the shot, and the content
        # cannot change mid-pick. Assumes monitor scale 1 — slurp's logical
        # coordinates must match grim's pixels.
        tmp_file="$(mktemp --suffix=.png)"
        grim "$tmp_file" || exit 1
        # slurp renders its own pointer from XCURSOR_THEME; hyprctl setcursor
        # does not reach it, so the camera cursor is passed via env.
        geometry="$(window_boxes | env XCURSOR_THEME="screenshot-camera" XCURSOR_SIZE="${XCURSOR_SIZE:-24}" slurp -r -b '#00000066' -c '#FFFFFFFF' -w 2 -s '#FFFFFF22' -f '%wx%h+%x+%y')" || exit 0
        magick "$tmp_file" -crop "$geometry" +repage "$file" || exit 1
        ;;
    crop)
        tmp_file="$(mktemp --suffix=.png)"
        grim "$tmp_file" || exit 1
        geometry="$(slurp -b '#00000066' -c '#FFFFFFFF' -w 2 -f '%wx%h+%x+%y')" || exit 0   # Escape cancels silently
        magick "$tmp_file" -crop "$geometry" +repage "$file" || exit 1
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
