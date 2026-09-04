# ==============================================================================
# Fix device model number in photo/video metadata
# ==============================================================================

LOG_BEGIN "Fixing device model number in photo/video metadata..."

while IFS= read -r f; do
    # Convert absolute path to relative for HEX_EDIT
    REL_PATH="${f#$WORKSPACE/}"
    HEX_EDIT "$REL_PATH" "726f2e70726f647563742e6d6f64656c00" "726f2e626f6f742e656d2e6d6f64656c00"
done < <(grep -r -w -l "ro.product.model" "$WORKSPACE/vendor" 2>/dev/null | grep "camera")

HEX_EDIT "system/system/lib64/libstagefright.so" \
    "726f2e70726f647563742e6d6f64656c00" "726f2e626f6f742e656d2e6d6f64656c00"

LOG_END "Device model fix applied successfully."
