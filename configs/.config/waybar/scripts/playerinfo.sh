#!/bin/bash

if ! playerctl status >/dev/null 2>&1; then
    echo '{"text": "", "tooltip": "No player active"}'
    exit 0
fi

player_name=$(playerctl metadata --format '{{playerName}}')
artist_title=$(playerctl metadata --format '{{artist}} - {{title}}')

artist_title_escaped=${artist_title//\"/\\\"}

maxlength=20
bar_text="$artist_title_escaped"

if [ ${#bar_text} -gt $maxlength ]; then
    bar_text="${bar_text:0:$maxlength-3}..."
fi

printf '{"text": "%s", "tooltip": "%s : %s"}\n' "$bar_text" "$player_name" "$artist_title_escaped"
