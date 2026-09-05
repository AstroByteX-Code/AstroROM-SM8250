# https://github.com/devcore94/MonsterROM/blob/seventeen/platform/exynos2100/patches/codec2/customize.sh
# ==============================================================================
# Codec2 patch
# ==============================================================================

LOG_BEGIN "- Applying codec2 patch"

CODEC2_POLICY="$WORKSPACE/vendor/etc/seccomp_policy/samsung.software.media.c2-base-policy"

if [ -f "$CODEC2_POLICY" ]; then
    LOG_INFO "Updating mremap rule in $(basename "$CODEC2_POLICY")"

    # Replace existing rule if present
    sed -i 's/^mremap: arg3 == 3$/mremap: arg3 == 3 || arg3 == MREMAP_MAYMOVE/' "$CODEC2_POLICY"

    # Append rule if not found
    if ! grep -q "mremap: arg3 == 3 || arg3 == MREMAP_MAYMOVE" "$CODEC2_POLICY"; then
        echo "mremap: arg3 == 3 || arg3 == MREMAP_MAYMOVE" >> "$CODEC2_POLICY"
    fi

    LOG_INFO "Updating build.prop with codec2 properties"

    # Ensure uniqueness before editing
    uniq "$WORKSPACE/system/system/build.prop" "$WORKSPACE/system/system/tmp" && \
        mv -f "$WORKSPACE/system/system/tmp" "$WORKSPACE/system/system/build.prop"

    # Add codec2 debug property
    sed -i "/spatializer_enabled=true/a debug.codec2.stop_hal_before_surface=1" \
        "$WORKSPACE/system/system/build.prop"

    # Add ro.audio.spatializer_enabled before stop_hal entry
    sed -i "/stop_hal_before_surface/i ro.audio.spatializer_enabled=true" \
        "$WORKSPACE/system/system/build.prop"

    # Add separator after PRODUCT_SYSTEM_DEFAULT_PROPERTIES
    sed -i "/PRODUCT_SYSTEM_DEFAULT_PROPERTIES/a ####################################" \
        "$WORKSPACE/system/system/build.prop"
fi

LOG_END "codec2 patch applied successfully"
