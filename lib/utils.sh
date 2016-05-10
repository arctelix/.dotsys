#!/bin/sh

rename_all() {
    . "$DOTSYS_LIBRARY/terminalio.sh"
    local files="$(find "$1" -type f -name "$2")"
    local file
    local new
    while IFS=$'\n' read -r file; do
        new="$(dirname "$file")/$3"
        get_user_input "rename $file -> $new"
        if [ $? -eq 0 ]; then
            mv "$file" "$new"
        fi

    done <<< "$files"
}

$@

