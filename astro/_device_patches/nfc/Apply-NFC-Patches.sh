# https://github.com/salvogiangri/UN1CA/blob/sixteen/unica/patches/nfc/customize.sh
# Author: @salvogiangri

if [ -f "$STOCK_FW/system/system/etc/libnfc-nci.conf" ]; then
    ADD_FROM_FW "stock" "system" "etc/libnfc-nci.conf"
else
    REMOVE "system" "etc/libnfc-nci.conf"
fi
if [ -f "$STOCK_FW/system/system/etc/libnfc-nci_temp.conf" ]; then
    ADD_FROM_FW "stock" "system" "etc/libnfc-nci_temp.conf"
else
    REMOVE "system" "etc/libnfc-nci_temp.conf"
fi
if [ -f "$STOCK_FW/system/system/etc/libnfc-nci-NXP_SN100U.conf" ]; then
    ADD_FROM_FW "stock" "system" "etc/libnfc-nci-NXP_SN100U.conf"
fi
if [ -f "$STOCK_FW/system/system/etc/libnfc-nci-NXP_PN553.conf" ]; then
    ADD_FROM_FW "stock" "system" "etc/libnfc-nci-NXP_PN553.conf"
fi
if [ -f "$STOCK_FW/system/system/etc/libnfc-nci-SLSI.conf" ]; then
    ADD_FROM_FW "stock" "system" "etc/libnfc-nci-SLSI.conf"
fi
if [ -f "$STOCK_FW/system/system/etc/libnfc-nci-STM_ST21.conf" ]; then
    ADD_FROM_FW "stock" "system" "etc/libnfc-nci-STM_ST21.conf"
fi

# Use a local variable to properly track and modify runtime chip state
CHIP_NAME="$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname" "stock")"
if [ "$CHIP_NAME" ]; then
    if [[ "$CHIP_NAME" == "NXP_PN553" ]]; then
        BPROP "vendor" "ro.vendor.nfc.feature.chipname" "NXP_SN100U"
        CHIP_NAME="NXP_SN100U"
    fi
    if ! [[ "$CHIP_NAME" =~ NXP_SN100U|SLSI|STM_ST21 ]]; then
        LOG_WARN "Unknown NFC chip name: $CHIP_NAME"
        return 0
    fi
fi

# SEC_PRODUCT_FEATURE_NFC_CHIP_NAME:=NXP_SN100U/NXP_PN553
# - API 35 and below: libnfc_nxpsn_jni.so/libnfc_nxppn_jni.so
# - API 36: libnfc_nci_jni.so

# 32-bit NXP Architecture Block
if [ -f "$WORKSPACE/system/system/lib/libnfc_nci_jni.so" ]; then
    if [ ! -f "$STOCK_FW/system/system/lib/libnfc_nci_jni.so" ] && \
            [ ! -f "$STOCK_FW/system/system/lib/libnfc_nxppn_jni.so" ] && \
            [ ! -f "$STOCK_FW/system/system/lib/libnfc_nxpsn_jni.so" ] && \
            [ ! -f "$WORKSPACE/vendor/lib/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORKSPACE/vendor/lib/nfc_nci_nxp.so" ] && \
            [ ! -f "$WORKSPACE/vendor/lib64/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORKSPACE/vendor/lib64/nfc_nci_nxp.so" ]; then
        REMOVE "system" "lib/libnfc_nci_jni.so"
        REMOVE "system" "lib/libnfc_prop_extn.so"
        REMOVE "system" "lib/libnfc_vendor_extn.so"
    fi
elif [ -f "$STOCK_FW/system/system/lib/libnfc_nci_jni.so" ]; then
    ADD_FROM_FW "stock" "system" "lib/libnfc_nci_jni.so"
    ADD_FROM_FW "stock" "system" "lib/libnfc_prop_extn.so"
    ADD_FROM_FW "stock" "system" "lib/libnfc_vendor_extn.so"
elif [ -f "$STOCK_FW/system/system/lib/libnfc_nxpsn_jni.so" ]; then
    LOG_WARN "Missing prebuilt blobs for 32-bit NXP_SN100U NFC chip"
    return 0
fi

# 64-bit NXP Architecture Block
if [ -f "$WORKSPACE/system/system/lib64/libnfc_nci_jni.so" ]; then
    if [ ! -f "$STOCK_FW/system/system/lib64/libnfc_nci_jni.so" ] && \
            [ ! -f "$STOCK_FW/system/system/lib64/libnfc_nxppn_jni.so" ] && \
            [ ! -f "$STOCK_FW/system/system/lib64/libnfc_nxpsn_jni.so" ] && \
            [ ! -f "$WORKSPACE/vendor/lib64/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORKSPACE/vendor/lib64/nfc_nci_nxp.so" ]; then
        REMOVE "system" "lib64/libnfc_nci_jni.so"
        REMOVE "system" "lib64/libnfc_prop_extn.so"
        REMOVE "system" "lib64/libnfc_vendor_extn.so"
    fi
elif [ -f "$STOCK_FW/system/system/lib64/libnfc_nci_jni.so" ]; then
    ADD_FROM_FW "stock" "system" "lib64/libnfc_nci_jni.so"
    ADD_FROM_FW "stock" "system" "lib64/libnfc_prop_extn.so"
    ADD_FROM_FW "stock" "system" "lib64/libnfc_vendor_extn.so"
elif [ -f "$STOCK_FW/system/system/lib64/libnfc_nxpsn_jni.so" ]; then
    LOG_WARN "Missing prebuilt blobs for 64-bit NXP_SN100U NFC chip"
    return 0
fi

# SEC_PRODUCT_FEATURE_NFC_CHIP_NAME:=STM_ST21
# - API 35 and below: libnfc_st_jni.so
# - API 36: libstnfc_nci_jni.so
if [ -f "$WORKSPACE/system/system/lib/libstnfc_nci_jni.so" ]; then
    if [ ! -f "$STOCK_FW/system/system/lib/libstnfc_nci_jni.so" ] && \
            [ ! -f "$STOCK_FW/system/system/lib64/libnfc_st_jni.so" ]; then
        REMOVE "system" "lib/libnfc_vendor_extn_st.so"
        REMOVE "system" "lib/libstnfc_nci_jni.so"
    fi
elif [ -f "$STOCK_FW/system/system/lib/libstnfc_nci_jni.so" ]; then
    ADD_FROM_FW "stock" "system" "lib/libnfc_vendor_extn_st.so"
    ADD_FROM_FW "stock" "system" "lib/libstnfc_nci_jni.so"
elif [ -f "$STOCK_FW/system/system/lib64/libnfc_st_jni.so" ]; then
    ADD_FROM_FW "a17" "system" "lib/libnfc_vendor_extn_st.so"
    ADD_FROM_FW "a17" "system" "lib/libstnfc_nci_jni.so"
fi
if [ -f "$WORKSPACE/system/system/lib64/libstnfc_nci_jni.so" ]; then
    if [ ! -f "$STOCK_FW/system/system/lib64/libstnfc_nci_jni.so" ] && \
            [ ! -f "$STOCK_FW/system/system/lib64/libnfc_st_jni.so" ]; then
        REMOVE "system" "lib64/libnfc_vendor_extn_st.so"
        REMOVE "system" "lib64/libstnfc_nci_jni.so"
    fi
elif [ -f "$STOCK_FW/system/system/lib64/libstnfc_nci_jni.so" ]; then
    ADD_FROM_FW "stock" "system" "lib64/libnfc_vendor_extn_st.so"
    ADD_FROM_FW "stock" "system" "lib64/libstnfc_nci_jni.so"
elif [ -f "$STOCK_FW/system/system/lib64/libnfc_st_jni.so" ]; then
    ADD_FROM_FW "a17" "system" "lib64/libnfc_vendor_extn_st.so"
    ADD_FROM_FW "a17" "system" "lib64/libstnfc_nci_jni.so"
fi

# SEC_PRODUCT_FEATURE_NFC_CHIP_NAME:=SLSI
# - Same lib name as before, check for TARGET_PLATFORM_SDK_VERSION instead
if [ -f "$WORKSPACE/system/system/lib64/libnfc_sec_jni.so" ]; then
    if [ ! -f "$STOCK_FW/system/system/lib64/libnfc_sec_jni.so" ] && \
            [ ! -f "$WORKSPACE/vendor/lib64/nfc_nci_sec.so" ]; then
        REMOVE "system" "lib64/libnfc_sec_jni.so"
    fi
elif [ -f "$STOCK_FW/system/system/lib64/libnfc_sec_jni.so" ]; then
    ADD_FROM_FW "r11s" "system" "lib/libnfc_sec_jni.so"
    ADD_FROM_FW "r11s" "system" "lib64/libnfc_sec_jni.so"
    mkdir -p "$WORKSPACE/system/system/priv-app/NfcNci/lib/arm64"    
    ln -sf "/system/lib64/libnfc_sec_jni.so" "$WORKSPACE/system/system/priv-app/NfcNci/lib/arm64/libnfc_sec_jni.so"
fi
