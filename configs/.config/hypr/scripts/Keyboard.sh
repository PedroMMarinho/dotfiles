#!/bin/bash

# Define Layouts
LAYOUTS=("keyboard-pt" "pinyin" "keyboard-us")

CURRENT=$(fcitx5-remote -n)

for i in "${!LAYOUTS[@]}"; do
    if [[ "${LAYOUTS[$i]}" == "$CURRENT" ]]; then
        CURRENT_INDEX=$i
        break
    fi
done

if [[ -z "$CURRENT_INDEX" ]]; then
    NEXT_INDEX=0
else
    NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#LAYOUTS[@]} ))
fi

fcitx5-remote -s "${LAYOUTS[$NEXT_INDEX]}"