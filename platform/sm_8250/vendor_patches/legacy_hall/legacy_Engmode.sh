# ==============================================================================
# Patch: Backport HIDL EngMode client
# Context:
#   - OneUI 9 system side uses AIDL EngMode client
#   - Legacy SM8250 vendor firmware still exposes HIDL 1.0 interface
#   - This patch injects legacy HIDL EngMode client libraries from stock firmware
#     so system and vendor remain compatible
# ==============================================================================

LOG_BEGIN "- Backporting HIDL EngMode client"

CURRENT_MANAGER="$WORKSPACE/system/system/lib64/lib.engmode.samsung.so"
VENDOR_INTERFACE="$WORKSPACE/vendor/lib64/vendor.samsung.hardware.security.engmode@1.0.so"
LEGACY_MANAGER="$STOCK_FW/system/system/lib64/lib.engmode.samsung.so"
LEGACY_INTERFACE="$STOCK_FW/system/system/lib64/vendor.samsung.hardware.security.engmode@1.0.so"

# Skip if current lib.engmode.samsung.so is missing
if [ ! -f "$CURRENT_MANAGER" ]; then
    LOG_INFO "Skipping: current lib.engmode.samsung.so not found"
    LOG_END "EngMode backport skipped"
    return 0
fi

# Skip if current lib already links HIDL directly (no backport needed)
if strings "$CURRENT_MANAGER" | grep -qF "vendor.samsung.hardware.security.engmode@1.0.so" && \
   ! strings "$CURRENT_MANAGER" | grep -qF "engmode-V1-ndk.so"; then
    LOG_INFO "Skipping: lib.engmode.samsung.so already uses HIDL directly"
    LOG_END "EngMode backport skipped"
    return 0
fi

# Skip if vendor interface is missing
if [ ! -f "$VENDOR_INTERFACE" ]; then
    LOG_WARN "Skipping: vendor HIDL EngMode interface missing"
    LOG_END "EngMode backport skipped"
    return 0
fi

# Abort if legacy libraries are missing in stock firmware
if [ ! -f "$LEGACY_MANAGER" ] || [ ! -f "$LEGACY_INTERFACE" ]; then
    ABORT "Legacy EngMode client libraries are missing in stock firmware"
fi

LOG_INFO "Injecting legacy HIDL EngMode client libraries from stock firmware"

# Context: These libraries are copied from the stock firmware tree
# to ensure compatibility with vendor HIDL 1.0 EngMode service
ADD_FROM_FW "stock" "system" "lib64/lib.engmode.samsung.so"
ADD_FROM_FW "stock" "system" "lib64/vendor.samsung.hardware.security.engmode@1.0.so"

# Add SELinux context for injected libraries
ADD_CONTEXT "system" "lib64/lib.engmode.samsung.so" "system_lib_file"
ADD_CONTEXT "system" "lib64/vendor.samsung.hardware.security.engmode@1.0.so" "system_lib_file"

LOG_END "EngMode client backport applied successfully"

