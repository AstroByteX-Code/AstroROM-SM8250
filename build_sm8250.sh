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

set -o pipefail

ASTROROM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ASTROROM

ROM_VERSION="3.7.0-"

BETA_ASSERT=0
BETA_OTA_URL=""
export BETA_ASSERT BETA_OTA_URL

DEBUG_BUILD=false

PREBUILTS=$ASTROROM/prebuilts

PROJECT_DIR="$ASTROROM/astro"
OBJECTIVES_DIR="$ASTROROM/objectives"
BLOBS_DIR="$ASTROROM/blobs"

AVAILABLE_DEVICES=()

if [[ -d "$OBJECTIVES_DIR" ]]; then
    for D in "$OBJECTIVES_DIR"/*/; do
        [[ -d "$D" ]] || continue
        AVAILABLE_DEVICES+=("$(basename "$D")")
    done
fi

WORKDIR="$ASTROROM/firmware/unpacked"
WORKSPACE="$ASTROROM/workspace"
DIROUT="$ASTROROM/out"

SOURCE_FW="${WORKDIR}/${MODEL}"
STOCK_FW="${WORKDIR}/${STOCK_MODEL}"
EXTRA_FW="${WORKDIR}/${EXTRA_MODEL}"

MARKER_FILE="$WORKSPACE/.build_markers"

PLATFORM=""
CODENAME=""

shopt -s globstar

for UTIL in "$ASTROROM"/scripts/**/*.sh; do
    if [[ -f "$UTIL" ]]; then
        source "$UTIL"
    fi
done

USE_THREADS() {
    local CPU_CORES
    local TOTAL_MEM_GB
    local THREADS
    local RAM_LIMIT

    CPU_CORES="$(nproc)"
    TOTAL_MEM_GB="$(free -g | awk '/^Mem:/{print $2}')"

    if IS_GITHUB_ACTIONS; then
        THREADS="$CPU_CORES"
    else
        THREADS="$((CPU_CORES - 1))"
    fi

    RAM_LIMIT="$((TOTAL_MEM_GB / 2))"

    if (( THREADS > RAM_LIMIT )); then
        THREADS="$RAM_LIMIT"
    fi

    (( THREADS < 1 )) && THREADS=1

    echo "$THREADS"
}

USABLE_THREADS="$(USE_THREADS)"

EXEC_SCRIPT()
{
    local SCRIPT_FILE="$1"
    local MARKER="$2"

    export SCRPATH
    SCRPATH=$(cd "$(dirname "$SCRIPT_FILE")" && pwd)

    local SCRIPT_PATHS="${SCRIPT_FILE#$ASTROROM/}"

    local CURRENT_HASH CACHED_HASH
    CURRENT_HASH=$(md5sum "$SCRIPT_FILE" 2>/dev/null | awk '{print $1}')
    [[ -z "$CURRENT_HASH" ]] && ERROR_EXIT "Hash failed: $SCRIPT_PATHS"

    CACHED_HASH=$(grep -F "$SCRIPT_FILE" "$MARKER" 2>/dev/null | awk '{print $2}')

    if [[ "$CACHED_HASH" == "$CURRENT_HASH" ]]; then
        return 0
    fi


    if ! source "$SCRIPT_FILE"; then
        local RC=$?
        ERROR_EXIT "Script failed in $SCRIPT_PATHS (exit $RC)"
    fi

    unset SCRPATH

    mkdir -p "$(dirname "$MARKER")"
    sed -i "\|^$SCRIPT_FILE |d" "$MARKER" 2>/dev/null || true
    echo "$SCRIPT_FILE $CURRENT_HASH" >> "$MARKER"
}

_BUILD_ROM()
{
    rm -rf "$ASTROROM/out" && mkdir -p "$ASTROROM/out"

    CHECK_ALL_DEPENDENCIES
    chmod +x -R "$PREBUILTS"

    if [[ -z "$DEVICE" ]]; then
        [[ ! -d "$OBJECTIVES_DIR" ]] && \
            ERROR_EXIT "objective folder not found: $OBJECTIVES_DIR"

        local DEVICES=()
        for D in "$OBJECTIVES_DIR"/*/; do
            [[ -d "$D" ]] || continue
            DEVICES+=("$(basename "$D")")
        done

        [[ ${#DEVICES[@]} -eq 0 ]] && \
            ERROR_EXIT "No objectives found in $OBJECTIVES_DIR"

        local CHOICE=$(_CHOICE "Available objectives" "${DEVICES[@]}")
        DEVICE="${DEVICES[CHOICE-1]}"
    fi

    OBJECTIVE="$OBJECTIVES_DIR/$DEVICE"
    export OBJECTIVE

    source "$OBJECTIVE/$DEVICE.sh" || ERROR_EXIT "Device config load failed"

    # Github Ubuntu runners have 72GB storage only. So skip extra firmwares
    if  IS_GITHUB_ACTIONS; then
        unset EXTRA_MODEL
        unset EXTRA_CSC
        unset EXTRA_IMEI
    fi

    local META_TAG="last_objective"
    local LAST_DEVICE=""
    local SCRIPT_COUNT=0
    local MARKER_EXISTS=false

    if [[ -f "$MARKER_FILE" ]]; then
        MARKER_EXISTS=true
        LAST_DEVICE=$(awk "/^$META_TAG / {print \$2}" "$MARKER_FILE")
        SCRIPT_COUNT=$(awk "!/^$META_TAG / {c++} END {print c+0}" "$MARKER_FILE")
    fi

    if ! $MARKER_EXISTS || [[ "$LAST_DEVICE" != "$DEVICE" ]] || [[ "$SCRIPT_COUNT" -eq 0 ]]; then
        LOG_INFO "Initializing device environment for $DEVICE"

        SETUP_DEVICE_ENV || ERROR_EXIT "environment setup failed"

# --- Vendor Replacement Block ---
# Run vendor replacement only for specific devices
case "$DEVICE" in
    x1q|y2q|z3q|r8q|c1q|c2q)
        VENDOR_PARTS_DIR="$ASTROROM/blobs/${DEVICE}_vendor"
        MERGED_VENDOR_IMG="$VENDOR_PARTS_DIR/vendor.img"

        LOG_BEGIN "Merging vendor parts into vendor.img for $DEVICE..."

        # Remove old merged file if exists
        rm -f "$MERGED_VENDOR_IMG"

        # Concatenate all parts (ensure correct order: part00, part01, ...)
        cat "$VENDOR_PARTS_DIR"/vendor.img.part* > "$MERGED_VENDOR_IMG" || ERROR_EXIT "Failed to merge vendor parts"

        LOG_INFO "Merged vendor.img created at $MERGED_VENDOR_IMG"

        # Verify Vendor Image
        if [[ ! -f "$MERGED_VENDOR_IMG" ]]; then
            ERROR_EXIT "Vendor image not found at: $MERGED_VENDOR_IMG"
        fi

        LOG_BEGIN "Replacing vendor with external image..."

        # 1. Remove existing vendor
        if [[ -d "$WORKSPACE/vendor" ]]; then
            LOG_INFO "Removing existing workspace vendor folder..."
            rm -rf "$WORKSPACE/vendor"
        fi

        # 2. Setup temporary extraction
        TEMP_EXTRACT_DIR="$WORKDIR/temp_vendor_extract"
        mkdir -p "$TEMP_EXTRACT_DIR"
        rm -rf "$TEMP_EXTRACT_DIR"/*

        # 3. Extract the new vendor image
        TEMP_FW_NAME="temp_vendor_fw"
        TEMP_FW_DIR="$WORKDIR/$TEMP_FW_NAME"

        rm -rf "$TEMP_FW_DIR"
        mkdir -p "$TEMP_FW_DIR"

        cp "$MERGED_VENDOR_IMG" "$TEMP_FW_DIR/vendor.img"

        LOG_INFO "Extracting vendor.img..."
        UNPACK_PARTITION "$TEMP_FW_DIR/vendor.img" "$TEMP_FW_NAME" || ERROR_EXIT "Failed to unpack vendor.img"

        # 4. Move extracted files to workspace
        EXTRACTED_VENDOR="$TEMP_FW_DIR/vendor"
        if [[ ! -d "$EXTRACTED_VENDOR" ]]; then
            ERROR_EXIT "Extraction seemingly failed. $EXTRACTED_VENDOR not found."
        fi

        LOG_INFO "Moving extracted vendor to workspace..."
        mv "$EXTRACTED_VENDOR" "$WORKSPACE/vendor"

        # 5. Handle Configs
        TEMP_CONFIG_DIR="$TEMP_FW_DIR/config"
        WORKSPACE_CONFIG_DIR="$WORKSPACE/config"
        mkdir -p "$WORKSPACE_CONFIG_DIR"

        if [[ -f "$TEMP_CONFIG_DIR/vendor_fs_config" ]]; then
            cp "$TEMP_CONFIG_DIR/vendor_fs_config" "$WORKSPACE_CONFIG_DIR/"
            LOG_INFO "Updated vendor_fs_config"
        else
            LOG_WARN "vendor_fs_config not found after extraction"
        fi

        if [[ -f "$TEMP_CONFIG_DIR/vendor_file_contexts" ]]; then
            cp "$TEMP_CONFIG_DIR/vendor_file_contexts" "$WORKSPACE_CONFIG_DIR/"
            LOG_INFO "Updated vendor_file_contexts"
        else
            LOG_WARN "vendor_file_contexts not found after extraction"
        fi

        rm -rf "$TEMP_FW_DIR"
        LOG_END "Vendor replacement complete for $DEVICE."
        ;;
    *)
        LOG_INFO "Skipping vendor replacement for device: $DEVICE"
        ;;
esac
# --- End Vendor Replacement Block ---



        mkdir -p "$(dirname "$MARKER_FILE")"
        sed -i "/^$META_TAG /d" "$MARKER_FILE" 2>/dev/null || true
        echo "$META_TAG $DEVICE" >> "$MARKER_FILE"
    fi

    local LAYERS=()

    if [[ -n "$PLATFORM" ]]; then
        PLATFORM_DIR="$ASTROROM/platform/$PLATFORM"
        LAYERS+=("$PLATFORM_DIR")
    fi

    LAYERS+=(
        "$PROJECT_DIR"
        "$OBJECTIVE"
    )

    for LAYER in "${LAYERS[@]}"; do
        [[ ! -d "$LAYER" ]] && continue

        # Execute scripts
        while IFS= read -r -d '' SH; do
            [[ "$SH" == *"$DEVICE.sh" ]] && continue


            local MOD_NAME MOD_AUTHOR

            MOD_NAME=$(grep "^# MOD_NAME=" "$SH" | cut -d'=' -f2- | sed 's/"//g;s/'\''//g')
            MOD_AUTHOR=$(grep "^# MOD_AUTHOR=" "$SH" | cut -d'=' -f2- | sed 's/"//g;s/'\''//g')

            if [[ -z "$MOD_NAME" ]]; then
                MOD_NAME=$(basename "$SH")
                LOG_BEGIN "Applying $MOD_NAME"
            else
                LOG_BEGIN "• $MOD_NAME"
                [[ -n "$MOD_AUTHOR" ]] && LOG "  └─ by $MOD_AUTHOR"
            fi


            EXEC_SCRIPT "$SH" "$MARKER_FILE"

        done < <(
            find "$LAYER" -type f -name "*.sh" \
                ! -path "*.apk/*" \
                ! -path "*.jar/*" \
                -print0 | sort -z | while IFS= read -r -d '' FILE; do

                DIR="$(dirname "$FILE")"
                PARENT="$DIR"
                SKIP_FILE=false

                while [[ "$PARENT" != "$LAYER" && "$PARENT" != "/" ]]; do
                    if [[ -f "$PARENT/.no" ]]; then
                        if [[ "$DIR" != "$PARENT" ]]; then
                            SKIP_FILE=true
                        fi
                        break
                    fi
                    PARENT="$(dirname "$PARENT")"
                done

                if [[ "$SKIP_FILE" == "false" ]]; then
                    printf '%s\0' "$FILE"
                fi
            done
        )

        # Append configs
        while IFS= read -r -d '' CFG; do
            NAME="$(basename "$CFG")"
            TARGET="$CONFIG_DIR/$NAME"

            if [[ ! -f "$TARGET" ]]; then
                cp "$CFG" "$TARGET"
            else
                while IFS= read -r LINE; do

                    PATH=$(echo "$LINE" | awk '{print $1}')
                    if [[ -n "$PATH" ]]; then
                        sed -i "\|^$PATH |d" "$TARGET"
                    fi
                    echo "$LINE" >> "$TARGET"
                done < "$CFG"
            fi
        done < <(find "$LAYER" -type f \( -name "*_file_contexts" -o -name "*_fs_config" \) -print0)

        # Sync partitions
        while IFS= read -r -d '' IMG; do
            PART=$(basename "$IMG" .img)
            if TARGET=$(GET_PARTITION_PATH "$PART" 2>/dev/null); then
                mkdir -p "$TARGET"
                rsync -a --no-links "$IMG/" "$TARGET/" \
                    || ERROR_EXIT "Adding files failed for $PART"
            else
                ERROR_EXIT "Unknown partition. $PART"
            fi
        done < <(find "$LAYER" -type d -name "*.img" -print0)
    done

    _APKTOOL_PATCH || ERROR_EXIT "APK/JAR patching failed"
    REPACK_ROM "$FILESYSTEM" || ERROR_EXIT "Repack failed"

    LOG_END "Build completed for $DEVICE"
}

show_usage()
{
cat <<EOF

AstroROM Build Tool v${ROM_VERSION}
Copyright (c) 2025 Sameer Al Sahab

USAGE:
 sudo ./build.sh [options] [command] [device:-optional]
  or
 sudo bash build.sh [options] [command] [device-optional]

COMMANDS:
  -b, --build [device]      Build ROM for a specific device.
                            If [device] is not given, a selection menu will appear.
  -c, --clean [option]      Cleanup build artifacts.
  -h, --help                Show usage.
      --ota-url [link]      Build astrorom from a beta firmware source.

CLEAN OPTIONS:
  -f, --firmware            Remove downloaded firmware files.
  -w, --workspace           Remove the workspace directory.
  --workdir                 Remove the unpacked firmware directory.
  --all                     Perform a full cleanup (firmware + workspace + workdir).

OPTIONS:
  -d, --debug               Build a debug rom for testing.

AVAILABLE OBJECTIVES:
  ${AVAILABLE_DEVICES[*]:-None found in $OBJECTIVES_DIR}


EXAMPLES:
  sudo ./build.sh build x1q
  sudo ./build.sh b
  sudo ./build.sh clean --workspace
  sudo ./build.sh clean --all


NOTE:
  Root privileges are required for build and clean operations.

EOF
}

cleanup_workspace()
{
    local TARGETS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--firmware)  TARGETS+=("$FW_DIR") ;;
            -w|--workspace) TARGETS+=("$WORKSPACE") ;;
            --all)
                TARGETS+=("$FW_DIR" "$WORKSPACE")
                ;;
            *)
                LOG_WARN "Unknown clean option: $1"
                ;;
        esac
        shift
    done

    [[ ${#TARGETS[@]} -eq 0 ]] && {
        LOG_WARN "Nothing to clean"
        return 0
    }

    for PATH in "${TARGETS[@]}"; do
        [[ -d "$PATH" ]] || continue
        LOG_INFO "Removing ${PATH#$ASTROROM/}"
        rm -rf "$PATH" || ERROR_EXIT "Failed to remove $PATH"
    done

    rm -f "$MARKER_FILE" 2>/dev/null || true
    LOG "Cleanup completed"
}

DEVICE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug|-d)
            DEBUG_BUILD=true
            shift
            ;;
        --build|-b)
            if [[ -n "$2" && "$2" != -* ]]; then
                DEVICE="$2"
                shift 2
            else
                shift 1
            fi
            ;;
        --clean|-c)
            cleanup_workspace "${@:2}"
            exit 0
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        --ota-url)
            [[ -z "$2" || "$2" == -* ]] && ERROR_EXIT "--ota-url requires a direct link"
            BETA_ASSERT=1
            BETA_OTA_URL="$2"
            export BETA_ASSERT BETA_OTA_URL
            shift 2
            ;;

        *)
            if [[ -z "$DEVICE" ]]; then
                DEVICE="$1"
            fi
            shift
            ;;
    esac
done

[[ $EUID -ne 0 ]] && ERROR_EXIT "Root required"

_BUILD_ROM
