#https://github.com/ShaDisNX255/NcX_Stock/commit/dc8a0872d0362dc7a1a723623558a73336193975

LOG_BEGIN "- Disabling ICE encryption in fstab.qcom"

LOG_BEGIN "- Disabling ICE/FBE encryption and removing Samsung ODE entries"

while IFS= read -r -d '' FSTAB; do
    LOG_INFO "Patching $(basename "$FSTAB")"

    # ---------------------------------------------------------
    # 1. Remove inlinecrypt from filesystem mount options
    # ---------------------------------------------------------
    sed -i -E \
        's/,inlinecrypt//g; s/inlinecrypt,//g; s/\binlinecrypt\b//g' \
        "$FSTAB"

    LOG_INFO "Removed inlinecrypt flag from mount options"

    # ---------------------------------------------------------
    # 2. Remove fileencryption from fs_mgr flags
    # ---------------------------------------------------------
    sed -i -E \
        's/,fileencryption=[^, ]*//g; s/fileencryption=[^, ]*,//g' \
        "$FSTAB"

    LOG_INFO "Removed fileencryption flag"

    # ---------------------------------------------------------
    # 3. Remove metadata encryption flags
    # ---------------------------------------------------------
    sed -i -E \
        's/,metadata_encryption[^, ]*//g; s/metadata_encryption[^, ]*,//g' \
        "$FSTAB"

    LOG_INFO "Removed metadata encryption flags"

    # ---------------------------------------------------------
    # 4. Remove keydirectory references
    # ---------------------------------------------------------
    sed -i -E \
        's/,keydirectory=[^, ]*//g; s/keydirectory=[^, ]*,//g' \
        "$FSTAB"

    LOG_INFO "Removed keydirectory flags"

    # ---------------------------------------------------------
    # 5. Remove Samsung ODE keydata/keyrefuge mount entries
    # ---------------------------------------------------------
    if grep -qE '(^|[[:space:]])/(keydata|keyrefuge)([[:space:]]|$)' "$FSTAB"; then
        LOG_INFO "Removing Samsung ODE keydata/keyrefuge entries"

        sed -i \
            -e '/^[[:space:]]*[^#].*[[:space:]]\/keydata[[:space:]]/d' \
            -e '/^[[:space:]]*[^#].*[[:space:]]\/keyrefuge[[:space:]]/d' \
            "$FSTAB"

        LOG_INFO "Removed Samsung ODE keydata/keyrefuge entries"
    fi

    # ---------------------------------------------------------
    # 6. Remove ODE comment if present
    # ---------------------------------------------------------
    sed -i '/^[[:space:]]*#.*Samsung ODE/d' "$FSTAB"

    # ---------------------------------------------------------
    # 7. Verify
    # ---------------------------------------------------------
    if grep -qE \
        'inlinecrypt|fileencryption=|metadata_encryption|keydirectory|keydata|keyrefuge' \
        "$FSTAB"; then

        LOG_WARN \
            "Encryption/ODE references still present in $(basename "$FSTAB")"

        grep -nE \
            'inlinecrypt|fileencryption=|metadata_encryption|keydirectory|keydata|keyrefuge' \
            "$FSTAB" || true
    else
        LOG_INFO \
            "No ICE/FBE/metadata encryption or ODE key references remain"
    fi

done < <(
    find "$WORKSPACE/vendor/etc" \
        -type f \
        -name "fstab*" \
        -print0
)

LOG_END "ICE/FBE encryption and Samsung ODE entries disabled"

LOG_END "Encryption disabled successfully"


# Disable FRP
BPROP "vendor"  "ro.frp.pst" ""
BPROP "product" "ro.frp.pst" ""

# vaultkeeper
BPROP "vendor" "ro.security.vaultkeeper.native" "0"
BPROP "vendor" "ro.security.vaultkeeper.feature" "0"

