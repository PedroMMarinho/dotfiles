#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing ags, waybar, rofi, swaync, wallust


# Kill already running processes
_ps=(waybar rofi swaync ags)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

# added since wallust sometimes not applying
killall -SIGUSR2 waybar 

# quit ags & relaunch ags
#ags -q && ags &

# quit quickshell & relaunch quickshell
#pkill qs && qs &

# some process to kill
# Added cava
for pid in $(pidof waybar rofi swaync ags swaybg cava); do
    kill -SIGUSR1 "$pid"
done

waybar &


swaync > /dev/null 2>&1 &
# reload swaync
swaync-client --reload-config
# For spotify There has to be a better way
# spicetify watch -s 

exit 0