#!/usr/bin/env bash

FASTFETCH_DIR="$XDG_CONFIG_HOME/fastfetch"
SYMLINK="$FASTFETCH_DIR/config.jsonc"

if [ -z "$1" ]; then
    echo "Usage: $0 <config_name>"
    echo "Available configs:"
    
    for file in "$FASTFETCH_DIR/configs"/*.jsonc; do
        [ -e "$file" ] || continue
        
        filename=$(basename "$file")
        
        echo "${filename%.jsonc}"
    done
    exit 1
fi

CONFIG_NAME="$1"
TARGET="$FASTFETCH_DIR/configs/${CONFIG_NAME}.jsonc"

if [ ! -f "$TARGET" ]; then
    echo "Error: config '$CONFIG_NAME' does not exist."
    exit 1
fi

if [ -e "$SYMLINK" ]; then
    rm "$SYMLINK"
fi

ln -s "$TARGET" "$SYMLINK"
echo "Switched $SYMLINK -> $TARGET"