#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: ./convert-cursor.sh <path_to_x11_cursor_folder>"
    exit 1
fi

INPUT_DIR="${1%/}" 
THEME_NAME="$(basename "$INPUT_DIR")"
EXTRACT_DIR="extracted_${THEME_NAME}"
HYPR_THEME_NAME="${THEME_NAME}_HYPR"

echo "Creating Hyprcursor theme for: $THEME_NAME..."

hyprcursor-util --extract "$INPUT_DIR" > /dev/null 2>&1

hyprcursor-util -c "$EXTRACT_DIR" > /dev/null 2>&1

mv -f "theme_Extracted Theme" "$HYPR_THEME_NAME"

rm -rf "$EXTRACT_DIR"

echo "✓ Done! Generated: $HYPR_THEME_NAME"
echo ""
echo "Next step: Move it to your icons folder:"
echo "cp -r \"$HYPR_THEME_NAME\" ~/.icons/"