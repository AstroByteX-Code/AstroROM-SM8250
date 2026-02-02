#!/bin/bash
#
#  Copyright (c) 2025 Sameer Al Sahab
#  Licensed under the MIT License. See LICENSE file for details.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#

TARGET_PARTITIONS=(system product system_ext odm vendor_dlkm odm_dlkm system_dlkm vendor)
CSC_SUB_PARTITIONS=(optics prism)



DETECT_FILESYSTEM() {
    local IMG="$1"
    local FS

    [[ ! -f "$IMG" ]] && { echo "unknown"; return 1; }

    FS=$(blkid -o value -s TYPE "$IMG" 2>/dev/null)
    if [[ -n "$FS" ]]; then
        echo "$FS"
        return 0
    fi

    if [[ "$(xxd -p -l 4 -s 1024 "$IMG" 2>/dev/null)" == "e0f5e1e2" ]]; then
        echo "erofs"
        return 0
    fi

    echo "unknown"
}


# https://source.android.com/docs/core/ota/dynamic_partitions
EXTRACT_FIRMWARE()
{
    local MODEL_NAME="$1"
    local REGION_CODE="$2"
    local FW_TYPE="$3"

    local SOURCE_DIR="${FW_BASE}/${MODEL_NAME}_${REGION_CODE}"
    local WORK_DIR="${WORKDIR}/${MODEL_NAME}"
    local CONF_FILE="${WORK_DIR}/unpack.conf"
    local MARKER_FILE="${WORK_DIR}/.extraction_complete"

    mkdir -p "$WORK_DIR"

    local AP_PACKAGE=$(find "$SOURCE_DIR" -maxdepth 1 \( -name "AP_*.tar.md5" -o -name "AP_*.tar" \) | head -1)
    local CSC_PACKAGE=$(find "$SOURCE_DIR" -maxdepth 1 \( -name "CSC_*.tar.md5" -o -name "CSC_*.tar" -o -name "HOME_CSC_*.tar.md5" -o -name "HOME_CSC_*.tar" \) | head -1)

    [[ -z "$AP_PACKAGE" ]] && { ERROR_EXIT "AP package missing for $MODEL_NAME"; return 1; }

    local FILE_STATE=$(_GET_FILE_STAT "$AP_PACKAGE")

# [ Check if we need to extract or not ;)
    if [[ -f "$CONF_FILE" ]]; then
        local CACHED_METADATA=$(source "$CONF_FILE" && echo "$METADATA")

        if [[ "$CACHED_METADATA" == "$FILE_STATE" && -f "$MARKER_FILE" ]]; then
            LOG_INFO "$MODEL_NAME firmware already extracted."
            return 0
        fi
    fi
# ]

    LOG_INFO "Unpacking $MODEL_NAME firmware..."
    rm -rf "${WORK_DIR:?}"/*
    mkdir -p "$WORK_DIR"


    local SUPER_IMG="${WORK_DIR}/super.img"

    FETCH_FILE "$AP_PACKAGE" "super.img" "$WORK_DIR" >/dev/null || {
        ERROR_EXIT "Failed to extract super.img from $AP_PACKAGE"
        return 1
    }

    # Github runner have limited 72GB Storage only :(
    if IS_GITHUB_ACTIONS; then rm -f "$AP_PACKAGE" && rm -rf "$SOURCE_DIR"; fi


    # Convert sparse to raw as lpunpack cannot take out images from sparse images
    SPARSE_TO_RAW "$SUPER_IMG" \
    || ERROR_EXIT "Sparse conversion failed for super.img"

	# [ Get super image metadata and unpack the super image
    #https://source.android.com/docs/core/ota/dynamic_partitions
    if [[ ! -f "$CONF_FILE" ]]; then
        local LPDUMP_OUT
        LPDUMP_OUT=$("$PREBUILTS/android-tools/lpdump" "$SUPER_IMG" 2>&1) || {
            rm -f "$CONF_FILE" "$MARKER_FILE"
            ERROR_EXIT "Failed to generate super metadata for $model"
        }

        local SUPER_SIZE METADATA_SIZE METADATA_SLOTS GROUP_NAME GROUP_SIZE
        SUPER_SIZE=$(echo "$LPDUMP_OUT" | awk '/Partition name: super/,/Flags:/ {if ($1 == "Size:") {print $2; exit}}')
        METADATA_SIZE=$(echo "$LPDUMP_OUT" | awk '/Metadata max size:/ {print $4}')
        METADATA_SLOTS=$(echo "$LPDUMP_OUT" | awk '/Metadata slot count:/ {print $4}')

        read -r GROUP_NAME GROUP_SIZE <<< $(echo "$LPDUMP_OUT" | awk '
            /Group table:/ {in_table=1}
            in_table && /Name:/ {name=$2}
            in_table && /Maximum size:/ {size=$3; if(size+0 > 0){print name, size; exit}}
        ')

        if [[ -n "$SUPER_SIZE" && -n "$GROUP_NAME" ]]; then

		cat > "$CONF_FILE" <<EOF
METADATA="$METADATA"
SUPER_SIZE="$SUPER_SIZE"
METADATA_SIZE="$METADATA_SIZE"
METADATA_SLOTS="$METADATA_SLOTS"
GROUP_NAME="$GROUP_NAME"
GROUP_SIZE="$GROUP_SIZE"
EXTRACT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
PARTITIONS=""
EOF
        else
            ERROR_EXIT "Failed to read super dynamic partition metadata"
        fi
    fi


    RUN_CMD "Extracting partitions" \
            "\"$PREBUILTS/android-tools/lpunpack\" \"$SUPER_IMG\" \"$WORK_DIR/\""
    # ]


    local FOUND_PART_COUNT=0
    for PART in "${TARGET_PARTITIONS[@]}"; do
	#https://source.android.com/docs/core/ota/ab
        for SUFFIX in "_a" ""; do
            local SRC_IMG="${WORK_DIR}/${PART}${SUFFIX}.img"
            local DST_IMG="${WORK_DIR}/${PART}.img"

            if [[ -f "$SRC_IMG" ]]; then
                [[ "$SRC_IMG" != "$DST_IMG" ]] && mv -f "$SRC_IMG" "$DST_IMG"
                UNPACK_PARTITION "$DST_IMG" "$MODEL_NAME"
                rm -f "$DST_IMG"
                ((FOUND_PART_COUNT++))
                break
            fi
        done
    done
	# Remove empty B slots (Virtual A/B)
    find "$WORK_DIR" -maxdepth 1 -type f -name "*_b.img" -delete


    # [ CSC Partitions
    if [[ -n "$CSC_PACKAGE" ]]; then
        for PART in "${CSC_SUB_PARTITIONS[@]}"; do
            local IMG_PATH="${WORK_DIR}/${PART}.img"
            if FETCH_FILE "$CSC_PACKAGE" "${PART}.img" "$WORK_DIR" >/dev/null 2>&1; then
                SPARSE_TO_RAW "$IMG_PATH" \
    || ERROR_EXIT "Cannot convert $IMG_PATH to raw"
                UNPACK_PARTITION "$IMG_PATH" "$MODEL_NAME"
                rm -f "$IMG_PATH"
                ((FOUND_PART_COUNT++))
            fi
        done
    fi
    # ]

    touch "$MARKER_FILE"
    LOG_END "Unpacked $MODEL_NAME firmware ($FOUND_PART_COUNT partitions)."
}

# https://source.android.com/docs/security/features/selinux/implement
UNPACK_PARTITION()
{
    local IMAGE_PATH="$1"
    local MODEL_NAME="$2"

    local PART_NAME=$(basename "$IMAGE_PATH" .img)
    local FS_TYPE=$(DETECT_FILESYSTEM "$IMAGE_PATH")
    local DEST_DIR="${WORKDIR}/${MODEL_NAME}/${PART_NAME}"
    local CONFIG_DIR="${WORKDIR}/${MODEL_NAME}/config"
    local UNPACK_CONF="${WORKDIR}/${MODEL_NAME}/unpack.conf"

    local FS_CONFIG="${CONFIG_DIR}/${PART_NAME}_fs_config"
    local FILE_CONT="${CONFIG_DIR}/${PART_NAME}_file_contexts"

    mkdir -p "$DEST_DIR" "$CONFIG_DIR"
    LOG_INFO "Extracting $PART_NAME [$FS_TYPE]..."

    local MNT=$(mktemp -d)
    trap 'umount "$MNT" &>/dev/null; rm -rf "$MNT"' RETURN


    case "$FS_TYPE" in
        "ext4") mount -o ro "$IMAGE_PATH" "$MNT" ;;
        "erofs") SILENT "$PREBUILTS/erofs-utils/fuse.erofs" "$IMAGE_PATH" "$MNT" ;;
        "f2fs") [[ ! IS_WSL ]] && mount -o ro "$IMAGE_PATH" "$MNT" ;;
        *)      ERROR_EXIT "Unsupported filesystem: $FS_TYPE"; return 1 ;;
    esac


    cp -a -T "$MNT" "$DEST_DIR"

    # Generate Linux perms & SELinux contexts
	#https://source.android.com/docs/security/features/selinux
	#https://source.android.com/docs/security/features/selinux/implement
    LOG_INFO "Extracting links, modes & attrs from $PART_NAME"

	# Generate fs_config: UID, GID, permissions, capabilities
    # Format: <path> <uid> <gid> <mode> capabilities=<capability_mask>
    find "$MNT" | xargs stat -c "%n %u %g %a capabilities=0x0" > "$FS_CONFIG"

	# Generate file_contexts: SELinux security contexts
    # Format: <path> <selinux_context>
    find "$MNT" | xargs -I {} sh -c 'echo "{} $(getfattr -n security.selinux --only-values -h --absolute-names "{}")"' sh > "$FILE_CONT"

    sort -o "$FS_CONFIG" "$FS_CONFIG"
    sort -o "$FILE_CONT" "$FILE_CONT"


    # [ System-as-root layout [/] | https://source.android.com/docs/core/architecture/partitions/system-as-root
    if [[ "$PART_NAME" == "system" ]] && [[ -d "$DEST_DIR/system" ]]; then
        sed -i -e "s|$MNT |/ |g" -e "s|$MNT||g" "$FILE_CONT"
        sed -i -e "s|$MNT | |g" -e "s|$MNT/||g" "$FS_CONFIG"
    else
	    # Other common partition layout [PART_NAME/]
        sed -i "s|$MNT|/$PART_NAME|g" "$FILE_CONT"
        sed -i -e "s|$MNT | |g" -e "s|$MNT|$PART_NAME|g" "$FS_CONFIG"
        sed -i '1s|^|/ |' "$FS_CONFIG"
    fi

    # Escape Regex metacharacters
    sed -i -E 's/([][()+*.^$?\\|])/\\\1/g' "$FILE_CONT"
    sed -i "/^PARTITIONS=/s/\"$/ $PART_NAME\"/" "$UNPACK_CONF"
    # ]
}

# https://source.android.com/docs/core/ota/sparse_images
SPARSE_TO_RAW() {
    local IMG="$1"

    [[ ! -f "$IMG" ]] && return 1

    if file "$IMG" | grep -qi "sparse"; then
        local RAW_IMG="${IMG%.img}.raw.img"
        LOG_INFO "Converting sparse to raw: $(basename "$IMG")"
        "$PREBUILTS/android-tools/simg2img" "$IMG" "$RAW_IMG" || return 1
        mv -f "$RAW_IMG" "$IMG"
    fi

    return 0
}



EXTRACT_ROM() {
    mkdir -p "$WORKDIR"

    local targets=(
        "$MODEL:$CSC:main"
        "${STOCK_MODEL:-}:$STOCK_CSC:stock"
        "${EXTRA_MODEL:-}:$EXTRA_CSC:extra"
    )

    local processed=""

    for entry in "${targets[@]}"; do
        IFS=":" read -r m c type <<< "$entry"
        [[ -z "$m" || -z "$c" ]] && continue

        DOWNLOAD_FW "$type" || ERROR_EXIT "Firmware download failed"

        local fw_id="${m}_${c}"
        if [[ "$processed" =~ "$fw_id" ]]; then
            continue
        fi


        if [[ "$type" == "main" && "$BETA_ASSERT" == "1" ]]; then
            PATCH_BETA_FW "$m" "$c" || return 1
        else
            EXTRACT_FIRMWARE "$m" "$c" "$type" || return 1
        fi

        processed+="$fw_id "
    done

    return 0
}
