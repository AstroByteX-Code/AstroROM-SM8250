#!/usr/bin/env bash
#
#  Copyright (c) 2025 Sameer Al Sahab
#  Licensed under the MIT License. See LICENSE file for details.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#

# [
_SANITIZE_PATH()
{
    realpath -m --relative-to=. "$1" | sed 's|^/||; s|/$||'
}

GET_FEATURE()
{
    local VAR_NAME="$1"
    local DEFAULT="${2:-false}"

    if ! declare -p "$VAR_NAME" &>/dev/null; then
        ERROR_EXIT
    fi

    local VAL="${!VAR_NAME,,}"

    case "$VAL" in
        true|1|y|yes|on)
            return 0 ;;
        false|0|n|no|off|"")
            return 1 ;;
        *)
            LOG_WARN "Invalid value for $VAR_NAME='$VAL'"
            ERROR_EXIT ;;
    esac
}


ADD_CONTEXT()
{
    local PARTITION="$1"
    local FILE_PATH="$2"
    local TYPE="$3"
    (( $# < 3 )) && ERROR_EXIT "USAGE: ADD_CONTEXT <PARTITION> <FILE_PATH> <TYPE>"
    local CONTEXT_FILE="${CONFIG_DIR}/${PARTITION}_file_contexts"
    FILE_PATH="${FILE_PATH#/}"
    local FULL_PATH="/${PARTITION}/${FILE_PATH}"
    TYPE="${TYPE%%:s0}"
    local CONTEXT="u:object_r:${TYPE}:s0"

    # Escape dots for file_contexts regex
    local ESCAPED_PATH
    ESCAPED_PATH="$(printf '%s\n' "$FULL_PATH" | sed 's/\./\\./g')"
    local EXACT_ENTRY="${ESCAPED_PATH} ${CONTEXT}"
    mkdir -p -- "$(dirname -- "$CONTEXT_FILE")"
    touch -- "$CONTEXT_FILE"

    grep -qxF -- "$EXACT_ENTRY" "$CONTEXT_FILE" && return 0

    local TMP_FILE
    TMP_FILE="$(mktemp)"

    grep -vxF -e "^${ESCAPED_PATH}[[:space:]]" "$CONTEXT_FILE" > "$TMP_FILE" 2>/dev/null || true
    printf '%s\n' "$EXACT_ENTRY" >> "$TMP_FILE"

    LC_ALL=C sort -u "$TMP_FILE" -o "$CONTEXT_FILE"
    rm -f -- "$TMP_FILE"
}


HEX_EDIT()
{
    local FILE_PATH="$1"
    local FROM_HEX="$2"
    local TO_HEX="$3"
    local FILE="${WORKSPACE}/${FILE_PATH}"

    if [[ -z "$FILE_PATH" ]] || [[ -z "$FROM_HEX" ]] || [[ -z "$TO_HEX" ]]; then
        ERROR_EXIT "Usage: HEX_EDIT <relative-path> <old-hex> <new-hex>"
        return 1
    fi

    if [[ ! -f "$FILE" ]]; then
        ERROR_EXIT "File not found: $FILE_PATH"
        return 1
    fi

    # Normalize patterns to lowercase
    FROM_HEX=$(tr '[:upper:]' '[:lower:]' <<< "$FROM_HEX")
    TO_HEX=$(tr '[:upper:]' '[:lower:]' <<< "$TO_HEX")

    # Get file's hex dump
    local FILE_HEX
    FILE_HEX=$(xxd -p "$FILE" | tr -d '\n ')

    # Check if already patched
    if grep -q "$TO_HEX" <<< "$FILE_HEX"; then
        LOG_INFO "Already patched: $FILE_PATH"
        return 0
    fi

    if ! grep -q "$FROM_HEX" <<< "$FILE_HEX"; then
        LOG_WARN "Pattern not found in file: $FROM_HEX"
        LOG_WARN "File: $FILE_PATH"
        return 1
    fi

    LOG_INFO "Patching $FROM_HEX → $TO_HEX in $FILE_PATH"

    if echo "$FILE_HEX" | sed "s/$FROM_HEX/$TO_HEX/" | xxd -r -p > "${FILE}.tmp"; then
        mv "${FILE}.tmp" "$FILE"
        return 0
    else
        ERROR_EXIT "Failed to apply patch to $FILE_PATH"
        rm -f "${FILE}.tmp"
        return 1
    fi
}

IS_GITHUB_ACTIONS()
{
    [[ "${GITHUB_ACTIONS}" == "true" || "${CI}" == "true" ]]
}

# https://github.com/canonical/snapd/blob/ec7ea857712028b7e3be7a5f4448df575216dbfd/release/release.go#L169-L190
IS_WSL()
{
    [ -e "/proc/sys/fs/binfmt_misc/WSLInterop" ] || [ -e "/run/WSL" ]
}

REPLACE_LINE()
{
    local OLD="$1"
    local NEW="$2"
    local FILE="$3"

    if [ ! -f "$FILE" ]; then
        ERROR_EXIT "File not found: $FILE"
    fi

    if grep -Fq "$NEW" "$FILE"; then
        LOG_WARN "Already patched in $FILE"
        return 0
    fi

    if grep -Fq "$OLD" "$FILE"; then
        LOG_INFO "Replacing old line with new line in $FILE"

        sed -i "s|$OLD|$NEW|g" "$FILE" \
            || ERROR_EXIT "Failed to patch $FILE"

        LOG_INFO "Replaced $OLD with $NEW successfully to $FILE"
        return 0
    fi

    ERROR_EXIT "Line not found in $FILE: '$OLD'"
}

_LOAD_MARKERS()
{
    PATCH_CACHE=()

    if [[ -f "$PATCH_MARKER_FILE" ]]; then
        while read -r TARGET_NAME HASH || [[ -n "$TARGET_NAME" ]]; do
            PATCH_CACHE["$TARGET_NAME"]="$HASH"
        done < "$PATCH_MARKER_FILE"
    fi
}

_UPDATE_MARKER()
{
    local TARGET_NAME="$1"
    local HASH="$2"
    local TEMP_FILE=$(mktemp)

    touch "$PATCH_MARKER_FILE"

    awk -v name="$TARGET_NAME" -v h="$HASH" '
        $1 == name { print name, h; found=1; next; }
        { print }
        END { if (!found) print name, h; }
    ' "$PATCH_MARKER_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$PATCH_MARKER_FILE"
}

CALC_HASH()
{
    local PATCH_DIR="$1"
    find "$PATCH_DIR" \( -name "*.patch" -o -name "*.smalipatch" \) -type f -exec md5sum {} + | \
        sort | md5sum | cut -d' ' -f1
}
# ]
