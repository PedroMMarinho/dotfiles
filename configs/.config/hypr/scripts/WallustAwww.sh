#!/bin/bash
# Wallust Colors for current wallpaper (using a single symlink)

# Define the path to the awww cache directory
cache_dir="$HOME/.cache/awww/"

# Get current focused monitor
current_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')
echo "$current_monitor"

# Construct the full path to the cache file
cache_file="$cache_dir$current_monitor"
echo "$cache_file"

if [ -f "$cache_file" ]; then
    # Get the wallpaper path from the cache file (Changed this so it would work)
    wallpaper_path=$(tr -d '\0' < "$cache_file" | awk -F 'Lanczos3' '{print $2}' | xargs)
    echo "$wallpaper_path"

    # Symlink the current wallpaper
    ln -sf "$wallpaper_path" "$HOME/.config/hypr/wallpaper_effects/current_wallpaper"

    # Execute Wallust
    echo 'about to execute wallust'
    wallust run "$wallpaper_path" &
fi
