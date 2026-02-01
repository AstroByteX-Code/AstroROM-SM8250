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
_GET_FILE_INODE()
{
    local FILE_PATH="$1"
    # Returns inode only
    stat -c "%i" "$FILE_PATH" 2>/dev/null || echo ""
}

_GET_MD5_HASH()
{
    local FILE_PATH="$1"
    md5sum "$FILE_PATH" 2>/dev/null | awk '{print $1}' | tr -d '[:space:]'
}

_GET_FILE_STAT()
{
    local FILE_PATH="$1"
    # %i=inode, %s=size, %Y=mtime
    stat -c "%i.%s.%Y" "$FILE_PATH" 2>/dev/null || echo "unknown"
}

#
# FETCH_FILE <container> <target_file> <output_directory>
#
FETCH_FILE()
{
    local CONTAINER="$1"
    local TARGET_FILE="$2"
    local OUT_DIR="$3"
    local DEPTH="${4:-0}"

    [[ -f "$CONTAINER" ]] || return 1
    mkdir -p "$OUT_DIR"

    local OUT_PATH="$OUT_DIR/$TARGET_FILE"
    [[ -s "$OUT_PATH" ]] && return 0

    (( DEPTH >= 5 )) && return 1

    if [[ -z "${IS_DEPS_OK:-}" ]]; then
        COMMAND_EXISTS 7z  || CHECK_DEPENDENCY p7zip-full "7zip" true
        COMMAND_EXISTS lz4 || CHECK_DEPENDENCY lz4 "lz4" true
        IS_DEPS_OK=1
    fi

    LOG_BEGIN "Fetching $TARGET_FILE from $(basename "$CONTAINER") (Depth: $DEPTH)"

    local FILE_LIST
    FILE_LIST="$(7z l "$CONTAINER" 2>/dev/null)" || return 1

    if echo "$FILE_LIST" | awk '{print $NF}' | grep -Fxq "$TARGET_FILE"; then
        7z x "$CONTAINER" "$TARGET_FILE" -so 2>/dev/null > "$OUT_PATH"
        [[ -s "$OUT_PATH" ]] && return 0
        rm -f "$OUT_PATH"
    fi

    if echo "$FILE_LIST" | awk '{print $NF}' | grep -Fxq "$TARGET_FILE.lz4"; then
        if 7z x "$CONTAINER" "$TARGET_FILE.lz4" -so 2>/dev/null \
            | lz4 -d -c > "$OUT_PATH"; then
            [[ -s "$OUT_PATH" ]] && return 0
        fi
        rm -f "$OUT_PATH"
    fi

    echo "$FILE_LIST" | awk '{print $NF}' \
        | grep -E '\.(tar(\.md5)?|zip|lz4|bin|img|7z|xz|gz)$' \
        | while read -r NODE; do

        local TMP_NODE
        TMP_NODE="$(mktemp "$OUT_DIR/tmp_$(basename "$NODE").XXXXXX")"

        7z x "$CONTAINER" "$NODE" -so 2>/dev/null > "$TMP_NODE" || {
            rm -f "$TMP_NODE"
            continue
        }

        if FETCH_FILE "$TMP_NODE" "$TARGET_FILE" "$OUT_DIR" "$((DEPTH + 1))"; then
            rm -f "$TMP_NODE"
            exit 0
        fi

        rm -f "$TMP_NODE"
    done

    return 1
}


EXISTS()
{
    local SOURCE_FIRMWARE
    local PARTITION_NAME
    local TARGET_PATH

    if [[ $# -eq 2 ]]; then
        SOURCE_FIRMWARE=""
        PARTITION_NAME="$1"
        TARGET_PATH="$2"
    elif [[ $# -eq 3 ]]; then
        SOURCE_FIRMWARE="$1"
        PARTITION_NAME="$2"
        TARGET_PATH="$3"
    else
        ERROR_EXIT "Usage: EXISTS [source] <partition> <path>"
        return 1
    fi

    local BASE_DIR
    BASE_DIR=$(GET_PARTITION_PATH "$PARTITION_NAME" "$SOURCE_FIRMWARE" 2>/dev/null) || return 1
    [[ ! -d "$BASE_DIR" ]] && return 1

    local SANITIZED_PATH
    SANITIZED_PATH=$(_SANITIZE_PATH "$TARGET_PATH")

    for MATCH in "$BASE_DIR"/$SANITIZED_PATH; do
        [[ -e "$MATCH" ]] && return 0
    done

    return 1
}

MERGE_SPLITS()
{
    local SRC_BASE="$1"
    local DESTINATION_FILE="$2"
    local SEARCH_MODE="$3"
    local PARTS=()

    if [[ "$SEARCH_MODE" == "DIR_CONTENTS" && -d "$SRC_BASE" ]]; then

        local FIRST
        FIRST=$(ls "$SRC_BASE"/*.part* "$SRC_BASE"/*.0[0-9]* "$SRC_BASE"/*.a[a-z] 2>/dev/null | head -n 1)

        if [[ -n "$FIRST" ]]; then

            local BASE_NAME
            BASE_NAME=$(basename "$FIRST" | sed -E 's/\.(part[0-9]+|[0-9]{2,}|[a-z]{2})$//')
            PARTS=($(ls "$SRC_BASE/$BASE_NAME."* "$SRC_BASE/${BASE_NAME}_part"* 2>/dev/null | sort))

            mkdir -p "$DESTINATION_FILE"
            DESTINATION_FILE="$DESTINATION_FILE/$BASE_NAME"
        fi

    elif [[ "$SEARCH_MODE" == "FILE_SUFFIX" ]]; then

        PARTS=($(ls "${SRC_BASE}".part* "${SRC_BASE}"*.[0-9][0-9]* "${SRC_BASE}"*.[a-z][a-z] 2>/dev/null | sort))
    fi

    if [[ ${#PARTS[@]} -gt 0 ]]; then
        mkdir -p "$(dirname "$DESTINATION_FILE")"
        cat "${PARTS[@]}" > "$DESTINATION_FILE" || ERROR_EXIT "Failed to merge splits to $DESTINATION_FILE"
        return 0
    fi

    return 1
}


ADD_FROM_FW()
{
    local SOURCE="$1"
    local SRC_PART="$2"
    local SRC_PATH="$3"
    local DESTINATION_PATH="${4:-$SRC_PART}"

    [[ -z "$SOURCE" || -z "$SRC_PART" || -z "$SRC_PATH" ]] && \
        ERROR_EXIT "Usage: ADD_FROM_FW <source> <src_partition> <src_path> [path_inside_partition]"

    VALIDATE_WORKDIR "$SOURCE" || ERROR_EXIT "Invalid source: $SOURCE"

    local SRC_DIR DST_DIR
    SRC_DIR=$(GET_PARTITION_PATH "$SRC_PART" "$SOURCE") || ERROR_EXIT "Unknown src partition: $SRC_PART"
    DST_DIR=$(GET_PARTITION_PATH "$DESTINATION_PATH") || ERROR_EXIT "Unknown dst partition: $DESTINATION_PATH"

    local CLEAN_PATH FULL_SRC FULL_DST
    CLEAN_PATH=$(_SANITIZE_PATH "$SRC_PATH")
    FULL_SRC="$SRC_DIR/$CLEAN_PATH"
    FULL_DST="$DST_DIR/$CLEAN_PATH"

    if [[ -d "$FULL_SRC" ]]; then
        if MERGE_SPLITS "$FULL_SRC" "$FULL_DST" "DIR_CONTENTS"; then
            return 0
        fi

        mkdir -p "$FULL_DST"

        LOG "Adding folder $CLEAN_PATH from $SOURCE"

        rsync -a --no-owner --no-group "$FULL_SRC/" "$FULL_DST/" || \
            ERROR_EXIT "Failed to copy folder $CLEAN_PATH"
        return 0

    fi

    if [[ -f "$FULL_SRC" ]]; then
        mkdir -p "$(dirname "$FULL_DST")"
        LOG "Adding file $CLEAN_PATH from $SOURCE"
        cp -f "$FULL_SRC" "$FULL_DST" || ERROR_EXIT "Copy failed: $CLEAN_PATH"
        return 0
    fi

    if MERGE_SPLITS "$FULL_SRC" "$FULL_DST" "FILE_SUFFIX"; then
        return 0
    fi

    LOG_WARN "Path not found in source: $CLEAN_PATH"
}


ADD()
{
    local PARTITION="$1"
    local SRC_PATH="$2"
    local DESTINATION_PATH="$3"
    local LABEL="${4:-$(basename "$SRC_PATH")}"

    local PART_ROOT FULL_DEST
    PART_ROOT=$(GET_PARTITION_PATH "$PARTITION") || \
        ERROR_EXIT "Add failed: partition '$PARTITION'"

    FULL_DEST="$PART_ROOT/$DESTINATION_PATH"

    [[ "$SRC_PATH" == "$FULL_DEST" ]] && return 0

    if [[ -d "$SRC_PATH" ]]; then

        mkdir -p "$FULL_DEST"
        LOG "Adding folder: $LABEL"

        rsync -a --no-owner --no-group "$SRC_PATH/" "$FULL_DEST/" || \
            ERROR_EXIT "Failed to add $LABEL"
        return 0
    fi

    if [[ -f "$SRC_PATH" ]]; then

        if [[ -d "$FULL_DEST" ]]; then
            FULL_DEST="$FULL_DEST/$(basename "$SRC_PATH")"
        fi

        mkdir -p "$(dirname "$FULL_DEST")"
        LOG "Adding file: $LABEL"
        cp -f "$SRC_PATH" "$FULL_DEST" || ERROR_EXIT "Copy failed: $LABEL"
        return 0
    fi

    if [[ ! -e "$SRC_PATH" ]]; then
        if MERGE_SPLITS "$SRC_PATH" "$FULL_DEST" "FILE_SUFFIX"; then
            return 0
        fi
    fi

    ERROR_EXIT "Source not found: $SRC_PATH"
}

#
# Removes file from workspace
# Usage REMOVE "partition" "path"
#
REMOVE()
{
    local PARTITION="$1"
    local PATH_INSIDE_PARTITION="$2"

    if [[ -z "$PARTITION" || -z "$PATH_INSIDE_PARTITION" ]]; then
        ERROR_EXIT "Missing arguments. Usage: REMOVE <partition> <path>"
    fi

    local BASE_DIR
    BASE_DIR=$(GET_PARTITION_PATH "$PARTITION" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        ERROR_EXIT "Failed to get partition directory for '$PARTITION'"
    fi

    local CLEAN_PATH
    CLEAN_PATH=$(_SANITIZE_PATH "$PATH_INSIDE_PARTITION")

    local FOUND_ANY=false

    for MATCH in "${BASE_DIR}"/$CLEAN_PATH; do

        [[ ! -e "$MATCH" && ! -L "$MATCH" ]] && continue

        FOUND_ANY=true

        # Remove from Disk
        if ! rm -rf "$MATCH" 2>/dev/null; then
            ERROR_EXIT "Failed to remove '$MATCH'"
        fi

        local ACTUAL_REL_PATH="${MATCH#$BASE_DIR/}"

        local ESCAPED_PATH
        ESCAPED_PATH=$(printf '%s' "$ACTUAL_REL_PATH" | sed 's/[.[\*^$()+?{|]/\\&/g')

        local FS_CONFIG_FILE="$WORKSPACE/config/${PARTITION}_fs_config"
        local FILE_CONTEXTS_FILE="$WORKSPACE/config/${PARTITION}_file_contexts"

        if [[ -f "$FS_CONFIG_FILE" ]]; then
            sed -i "\|^${PARTITION}/${ESCAPED_PATH}\(/\|[[:space:]]\)|d" "$FS_CONFIG_FILE"
        fi

        if [[ -f "$FILE_CONTEXTS_FILE" ]]; then
            sed -i "\|^/${PARTITION}/${ESCAPED_PATH}\(/\|[[:space:]]\)|d" "$FILE_CONTEXTS_FILE"
        fi
    done

    if [[ "$FOUND_ANY" = false ]]; then
        LOG_WARN "No files matching '${PARTITION}/${CLEAN_PATH}' found to remove."
    fi

    return 0
}
# ]
