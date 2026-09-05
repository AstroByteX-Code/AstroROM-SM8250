# ==============================================================================
#
# MOD_NAME="Bluetooth library patcher"
# MOD_AUTHOR="3arthur6 & duhansysl"
# MOD_DESC="Fixes Bluetooth and forget issues."
#
# ==============================================================================

BT_LIB_PATCH() {
    local APEX_FILE CLEANED_PATH SDK_VERSION_FULL PATCH_APPLIED=false
    local LIB_PATH="system/system/lib64/libbluetooth_jni.so"

    APEX_FILE=$(find "$WORKSPACE/system/system/apex" -name "com.android.bt*.apex" 2>/dev/null | head -n1)
    [[ -z "$APEX_FILE" ]] && ERROR_EXIT "No Bluetooth APEX found"

    CLEANED_PATH="${APEX_FILE#$WORKSPACE/}"

    EXTRACT_FROM_APEX_PAYLOAD "$CLEANED_PATH" \
        "lib64/libbluetooth_jni.so" \
        "$LIB_PATH"

    [[ ! -f "$WORKSPACE/$LIB_PATH" ]] && ERROR_EXIT "Bluetooth JNI library not extracted"

    SDK_VERSION_FULL="$(GET_PROP "system" "ro.build.version.sdk")"
    LOG_INFO "Detected SDK version: $SDK_VERSION_FULL"

    # Each entry: "OLD_HEX NEW_HEX"
    local PATCHES=()

    case "$SDK_VERSION_FULL" in
        33|33.0)
            PATCHES=("6804003528008052 2a00001428008052")
            ;;
        34|34.0)
            PATCHES=("6804003528008052 2b00001428008052")
            ;;
        35|35.0)
            PATCHES=("480500352800805228 530100142800805228")
            ;;
        36|36.0)
            PATCHES=(
                "00122a0140395f01086b00020054 00122a0140395f01086bde030014"
                "2897773948050037 289777392a000014"
                "2897673948050037 289767392a000014"
                "183a009048050037 183a00902a000014"
                "3a009048050037330080 3a00902a000014330080"
                "f6713948050037330080 f671392a000014330080"
                "97753948050037360080 9775392a000014360080"
                "97773948050037360080 9777392a000014360080"
                "3a009048050037330080 3a00902a000014330080"
                "f6713948050037330080 f671392a000014330080"
                "f6733948050037330080 f673392a000014330080"
                "76743948050037330080 7674392a000014330080"
            )
            ;;
        *)
            LOG_WARN "Unsupported SDK version: $SDK_VERSION_FULL"
            ;;
    esac

    for P in "${PATCHES[@]}"; do
        set -- $P
        if HEX_EDIT "$LIB_PATH" "$1" "$2"; then
            PATCH_APPLIED=true
        fi
    done

    [[ "$PATCH_APPLIED" != true ]] && \
        LOG_WARN "No patch applied for Bluetooth library (SDK $SDK_VERSION_FULL)"

    return 0
}

if ! EXISTS "system" "lib64/libbluetooth_jni.so"; then
    LOG_BEGIN "Applying Bluetooth library patch"

    BT_LIB_PATCH || LOG_WARN "Bluetooth patching failed"

    LOG_END "Bluetooth library patch applied successfully"
fi
