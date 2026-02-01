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
# Applies Over-The-Air (OTA) updates from beta firmware packages to existing
# firmware images.

EXTRA_HEADROOM=10

PATCH_BETA_FW()
{
    local DEVICE_MODEL="$1"
    local DEVICE_CSC="$2"

    local ODIN_PACKAGE_DIR="${FW_BASE}/${DEVICE_MODEL}_${DEVICE_CSC}"
    local FIRMWARE_WORK_DIR="${WORKDIR}/${DEVICE_MODEL}"
    local BETA_OTA_DIR="$WORKDIR/beta_ota"
    local EXTRACTION_CONFIG_FILE="${FIRMWARE_WORK_DIR}/unpack.conf"
    local PATCH_TOOLS_DIR="$PREBUILTS/imgpatchtools"

    local TARGET_PARTITION_LIST=(
        system
        product
        system_ext
        odm
        vendor_dlkm
        odm_dlkm
        system_dlkm
        vendor
    )

    LOG_BEGIN "Extracting firmware for $DEVICE_MODEL"

    mkdir -p "$FIRMWARE_WORK_DIR" "$BETA_OTA_DIR"

    local AP_PACKAGE_PATH
    AP_PACKAGE_PATH=$(find "$ODIN_PACKAGE_DIR" -maxdepth 1 \( -name "AP_*.tar.md5" -o -name "AP_*.tar" \) | head -1)
    [[ -z "$AP_PACKAGE_PATH" ]] && { ERROR_EXIT "AP package missing for $DEVICE_MODEL"; return 1; }

    local CURRENT_PACKAGE_METADATA
    CURRENT_PACKAGE_METADATA=$(_GET_FILE_STAT "$AP_PACKAGE_PATH")

    if [[ -f "$EXTRACTION_CONFIG_FILE" ]]; then
        local CACHED_PACKAGE_METADATA
        CACHED_PACKAGE_METADATA=$(source "$EXTRACTION_CONFIG_FILE" && echo "$METADATA")
        if [[ "$CACHED_PACKAGE_METADATA" == "$CURRENT_PACKAGE_METADATA" && -f "${FIRMWARE_WORK_DIR}/.extraction_complete" ]]; then
            LOG_INFO "$DEVICE_MODEL firmware already extracted and merged."
            return 0
        fi
    fi

    LOG_INFO "Unpacking $DEVICE_MODEL firmware..."
    rm -rf "${FIRMWARE_WORK_DIR:?}"/*
    mkdir -p "$FIRMWARE_WORK_DIR"

    local SUPER_IMAGE_PATH="$FIRMWARE_WORK_DIR/super.img"
    FETCH_FILE "$AP_PACKAGE_PATH" "super.img" "$FIRMWARE_WORK_DIR" >/dev/null || {
        rm -f "$EXTRACTION_CONFIG_FILE" "${FIRMWARE_WORK_DIR}/.extraction_complete"
        ERROR_EXIT "Failed to extract super.img from $AP_PACKAGE_PATH"
        return 1
    }

    if IS_GITHUB_ACTIONS; then
        rm -f "$AP_PACKAGE_PATH"
        rm -rf "$ODIN_PACKAGE_DIR"
    fi

    if [[ ! -f "$BETA_OTA_DIR/beta.zip" ]]; then
        LOG_INFO "Downloading beta OTA package..."
        curl -fL --user-agent "Mozilla/5.0" "$BETA_OTA_URL" -o "$BETA_OTA_DIR/beta.zip" || {
            ERROR_EXIT "Download failed. The URL might be expired or blocked."
            return 1
        }
    fi

    if [[ ! -f "$BETA_OTA_DIR/system.transfer.list" ]]; then
        LOG_INFO "Extracting beta OTA package..."
        unzip -q -o "$BETA_OTA_DIR/beta.zip" -d "$BETA_OTA_DIR" || { ERROR_EXIT "Unzip failed"; return 1; }
    fi

    if [[ ! -f "$EXTRACTION_CONFIG_FILE" ]]; then
        local RAW_SUPER_IMAGE_PATH="$FIRMWARE_WORK_DIR/super.raw"
        if file "$SUPER_IMAGE_PATH" | grep -q "sparse"; then
            "$PREBUILTS/android-tools/simg2img" "$SUPER_IMAGE_PATH" "$RAW_SUPER_IMAGE_PATH" >/dev/null
        else
            cp "$SUPER_IMAGE_PATH" "$RAW_SUPER_IMAGE_PATH"
        fi

        local LPDUMP_OUTPUT
        LPDUMP_OUTPUT=$("$PREBUILTS/android-tools/lpdump" "$RAW_SUPER_IMAGE_PATH" 2>&1)

        local SUPER_PARTITION_SIZE METADATA_MAX_SIZE METADATA_SLOT_COUNT
        local DYNAMIC_PARTITION_GROUP_NAME DYNAMIC_PARTITION_GROUP_SIZE

        SUPER_PARTITION_SIZE=$(echo "$LPDUMP_OUTPUT" | awk '/Partition name: super/,/Flags:/ {if ($1=="Size:") {print $2; exit}}')
        METADATA_MAX_SIZE=$(echo "$LPDUMP_OUTPUT" | awk '/Metadata max size:/ {print $4}')
        METADATA_SLOT_COUNT=$(echo "$LPDUMP_OUTPUT" | awk '/Metadata slot count:/ {print $4}')
        read -r DYNAMIC_PARTITION_GROUP_NAME DYNAMIC_PARTITION_GROUP_SIZE <<< $(echo "$LPDUMP_OUTPUT" | awk '/Group table:/ {in_table=1} in_table && /Name:/ {name=$2} in_table && /Maximum size:/ {size=$3; if(size+0>0){print name,size; exit}}')

        cat > "$EXTRACTION_CONFIG_FILE" <<EOF
METADATA="$CURRENT_PACKAGE_METADATA"
SUPER_SIZE="$SUPER_PARTITION_SIZE"
METADATA_SIZE="$METADATA_MAX_SIZE"
METADATA_SLOTS="$METADATA_SLOT_COUNT"
GROUP_NAME="$DYNAMIC_PARTITION_GROUP_NAME"
GROUP_SIZE="$DYNAMIC_PARTITION_GROUP_SIZE"
EXTRACT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
PARTITIONS=""
EOF
        rm -f "$RAW_SUPER_IMAGE_PATH"
    fi

    LOG_INFO "Extracting sparse partitions from super..."
    7z x "$SUPER_IMAGE_PATH" -o"$FIRMWARE_WORK_DIR" "*.img" -y >/dev/null 2>&1
    rm -f "$SUPER_IMAGE_PATH"

    LOG_BEGIN "Applying beta OTA patches.."

    local PARTITION_RESIZE_LIST="$BETA_OTA_DIR/dynamic_partitions_op_list"
    if [[ -f "$PARTITION_RESIZE_LIST" ]]; then
        while read -r OPERATION_TYPE PARTITION_NAME TARGET_SIZE; do
            [[ "$OPERATION_TYPE" != "resize" ]] && continue

            local PARTITION_IMAGE_PATH="$FIRMWARE_WORK_DIR/$PARTITION_NAME.img"
            [[ ! -f "$PARTITION_IMAGE_PATH" ]] && PARTITION_IMAGE_PATH="$FIRMWARE_WORK_DIR/${PARTITION_NAME}_a.img"

            if [[ -f "$PARTITION_IMAGE_PATH" ]]; then
                local SIZE_WITH_HEADROOM=$((TARGET_SIZE + (TARGET_SIZE * EXTRA_HEADROOM / 100)))
                LOG_INFO "Resizing ${COLOR_CYAN}${PARTITION_NAME}${COLOR_RESET} to ${COLOR_GREEN}${SIZE_WITH_HEADROOM}${COLOR_RESET} bytes (${EXTRA_HEADROOM}% headroom)"
                truncate -s "$SIZE_WITH_HEADROOM" "$PARTITION_IMAGE_PATH"
            fi
        done < "$PARTITION_RESIZE_LIST"
    fi

    for PARTITION_NAME in "${TARGET_PARTITION_LIST[@]}"; do
        local PARTITION_IMAGE_PATH=""

        for PARTITION_SUFFIX in "_a" ""; do
            if [[ -f "$FIRMWARE_WORK_DIR/${PARTITION_NAME}${PARTITION_SUFFIX}.img" ]]; then
                PARTITION_IMAGE_PATH="$FIRMWARE_WORK_DIR/${PARTITION_NAME}${PARTITION_SUFFIX}.img"
                if [[ "$PARTITION_SUFFIX" == "_a" ]]; then
                    mv "$PARTITION_IMAGE_PATH" "$FIRMWARE_WORK_DIR/$PARTITION_NAME.img"
                    PARTITION_IMAGE_PATH="$FIRMWARE_WORK_DIR/$PARTITION_NAME.img"
                fi
                break
            fi
        done

        [[ -z "$PARTITION_IMAGE_PATH" ]] && continue

        if [[ -f "$BETA_OTA_DIR/$PARTITION_NAME.transfer.list" ]]; then
            LOG_INFO "Patching ${COLOR_CYAN}${PARTITION_NAME}${COLOR_RESET}..."
            SILENT "$PATCH_TOOLS_DIR/BlockImageUpdate" \
                "$PARTITION_IMAGE_PATH" \
                "$BETA_OTA_DIR/$PARTITION_NAME.transfer.list" \
                "$BETA_OTA_DIR/$PARTITION_NAME.new.dat" \
                "$BETA_OTA_DIR/$PARTITION_NAME.patch.dat" || { ERROR_EXIT "$PARTITION_NAME patch failed"; return 1; }
        fi

        UNPACK_PARTITION "$PARTITION_IMAGE_PATH" "$DEVICE_MODEL" || { ERROR_EXIT "Failed to unpack $PARTITION_NAME"; return 1; }
        rm -f "$PARTITION_IMAGE_PATH"
    done

    find "$FIRMWARE_WORK_DIR" -maxdepth 1 -type f -name "*_b.img" -delete
    touch "${FIRMWARE_WORK_DIR}/.extraction_complete"

    if [[ -n "${SUDO_USER:-}" ]]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$WORKDIR"
        chmod -R 755 "$WORKDIR"
    fi

    rm -rf "$BETA_OTA_DIR"

    return 0
}
# ]
