# ==============================================================================
# Patch: Backport HIDL VaultKeeper client
# Context:
#   - OneUI 9 system side uses AIDL VaultKeeper client
#   - Legacy SM8250 vendor firmware still exposes HIDL 2.0 interface
#   - This patch injects legacy HIDL client libraries from stock firmware
#     so system and vendor remain compatible
# ==============================================================================

LOG_BEGIN "- Backporting HIDL VaultKeeper client"

CURRENT_MANAGER="$WORKSPACE/system/system/lib64/libvkmanager.so"
VENDOR_INTERFACE="$WORKSPACE/vendor/lib64/vendor.samsung.hardware.security.vaultkeeper@2.0.so"
LEGACY_MANAGER="$STOCK_FW/system/system/lib64/libvkmanager.so"
LEGACY_INTERFACE="$STOCK_FW/system/system/lib64/vendor.samsung.hardware.security.vaultkeeper@2.0.so"

# Skip if current libvkmanager is missing
if [ ! -f "$CURRENT_MANAGER" ]; then
    LOG_INFO "Skipping: current libvkmanager.so not found"
    LOG_END "VaultKeeper backport skipped"
    return 0
fi

# Skip if current libvkmanager already links HIDL directly (no backport needed)
if strings "$CURRENT_MANAGER" | grep -qF "vendor.samsung.hardware.security.vaultkeeper@2.0.so" && \
   ! strings "$CURRENT_MANAGER" | grep -qF "vaultkeeper-V1-ndk.so"; then
    LOG_INFO "Skipping: libvkmanager.so already uses HIDL directly"
    LOG_END "VaultKeeper backport skipped"
    return 0
fi

# Skip if vendor interface is missing
if [ ! -f "$VENDOR_INTERFACE" ]; then
    LOG_WARN "Skipping: vendor HIDL VaultKeeper interface missing"
    LOG_END "VaultKeeper backport skipped"
    return 0
fi

# Abort if legacy libraries are missing in stock firmware
if [ ! -f "$LEGACY_MANAGER" ] || [ ! -f "$LEGACY_INTERFACE" ]; then
    ABORT "Legacy VaultKeeper client libraries are missing in stock firmware"
fi

LOG_INFO "Injecting legacy HIDL VaultKeeper client libraries from stock firmware"

# Context: These libraries are copied from the stock firmware tree
# to ensure compatibility with vendor HIDL 2.0 VaultKeeper service
ADD_FROM_FW "stock" "system" "lib64/libvkmanager.so"
ADD_FROM_FW "stock" "system" "lib64/vendor.samsung.hardware.security.vaultkeeper@2.0.so"

# Add SELinux context for injected libraries
ADD_CONTEXT "system" "lib64/libvkmanager.so" "system_file"
ADD_CONTEXT "system" "lib64/vendor.samsung.hardware.security.vaultkeeper@2.0.so" "system_file"

LOG_END "VaultKeeper client backport applied successfully"
