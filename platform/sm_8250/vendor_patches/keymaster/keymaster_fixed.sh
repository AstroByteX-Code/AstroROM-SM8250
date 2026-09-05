# ==============================================================================
# Patch: Fix StrongBox Keymaster RC + Disable stale wait_for_keymaster
# Context:
#   - Injects missing 'interface' line into android.hardware.keymaster@4.0-strongbox-service-qti.rc
#   - Comments out stale exec_start wait_for_keymaster in init.target.rc to prevent boot stalls
# ==============================================================================


# FIX_STRONGBOX_KEYMASTER_RC()
{
    LOG_BEGIN "- Fixing StrongBox Keymaster RC"

    RC="$WORKSPACE/vendor/etc/init/android.hardware.keymaster@4.0-strongbox-service-qti.rc"

    if [ ! -f "$RC" ]; then
        LOG_INFO "Skipping: strongbox-service-qti.rc not found"
        LOG_END "StrongBox Keymaster RC fix skipped"
        return 0
    fi

    LOG_INFO "Checking for strongbox interface line in $RC"
    if ! grep -q "^    interface android\.hardware\.keymaster@4\.0::IKeymasterDevice strongbox$" "$RC"; then
        LOG_INFO "Injecting missing strongbox interface line"
        sed -i '/^service keymaster-sb-4-0 /a \    interface android.hardware.keymaster@4.0::IKeymasterDevice strongbox' "$RC"
        LOG_INFO "Strongbox interface line added"
    else
        LOG_INFO "Strongbox interface already present"
    fi

    LOG_END "StrongBox Keymaster RC fix applied successfully"
}

_DISABLE_STALE_KEYMASTER_WAIT()
{
    LOG_BEGIN "- Disabling stale wait_for_keymaster init hook"

    INIT_RC="$WORKSPACE/vendor/etc/init/hw/init.target.rc"

    if [ ! -f "$INIT_RC" ]; then
        LOG_INFO "Skipping: init.target.rc not found"
        LOG_END "Stale wait_for_keymaster disable skipped"
        return 0
    fi

    LOG_INFO "Searching for exec_start wait_for_keymaster in $INIT_RC"
    if grep -q "exec_start wait_for_keymaster" "$INIT_RC"; then
        sed -i 's/^\([[:space:]]*\)exec_start wait_for_keymaster$/\1#exec_start wait_for_keymaster/g' "$INIT_RC"
        LOG_INFO "exec_start wait_for_keymaster commented out"
    else
        LOG_INFO "No exec_start wait_for_keymaster line found"
    fi

    LOG_END "Stale wait_for_keymaster hook disabled successfully"
}

_DISABLE_STALE_KEYMASTER_WAIT
