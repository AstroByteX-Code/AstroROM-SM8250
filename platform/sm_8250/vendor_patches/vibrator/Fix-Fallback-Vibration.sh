# ==============================================================================
# Patch: Fix Vibration HAL (AstroROM style)
# Context:
#   - Removes outdated vibrator HAL/service stubs
#   - Injects stable V3 NDK platform blobs from y2q firmware
#   - Registers context for proper packaging and HAL execution
# ==============================================================================

LOG_BEGIN "Fixing Vibration..."

# Remove old vibrator HAL/service stubs
SILENT REMOVE "vendor" "bin/hw/vendor.samsung.hardware.vibrator@2.2-service"
SILENT REMOVE "vendor" "etc/init/vendor.samsung.hardware.vibrator@2.2-service.rc"
SILENT REMOVE "vendor" "lib64/vendor.samsung.hardware.vibrator@2.0.so"
SILENT REMOVE "vendor" "lib64/vendor.samsung.hardware.vibrator@2.1.so"
SILENT REMOVE "vendor" "lib64/vendor.samsung.hardware.vibrator@2.2.so"
SILENT REMOVE "vendor" "lib64/vendor.samsung.hardware.vibrator-V3-ndk_platform.so"
SILENT REMOVE "vendor" "etc/init/vendor.samsung.hardware.vibrator-default.rc"
SILENT REMOVE "vendor" "bin/hw/vendor.samsung.hardware.vibrator-service"
SILENT REMOVE "vendor" "etc/vintf/manifest/vendor.samsung.hardware.vibrator-default.xml"
LOG_INFO "Removed outdated vibrator HAL and service stubs"

# Inject stable vibrator blobs from y2q firmware
ADD_FROM_FW "y2q" "vendor" "lib64/vendor.samsung.hardware.vibrator-V3-ndk_platform.so"
ADD_FROM_FW "y2q" "vendor" "etc/init/vendor.samsung.hardware.vibrator-default.rc"
ADD_FROM_FW "y2q" "vendor" "bin/hw/vendor.samsung.hardware.vibrator-service"
ADD_FROM_FW "y2q" "vendor" "etc/vintf/manifest/vendor.samsung.hardware.vibrator-default.xml"
LOG_INFO "Injected vibrator V3 NDK platform blobs from y2q firmware"

# Register context for vibrator blobs
ADD_CONTEXT "vendor" "lib64/vendor.samsung.hardware.vibrator-V3-ndk_platform.so" "vendor_file"
ADD_CONTEXT "vendor" "etc/vintf/manifest/vendor.samsung.hardware.vibrator-default.xml" "vendor_configs_file"
ADD_CONTEXT "vendor" "etc/init/vendor.samsung.hardware.vibrator-default.rc" "vendor_configs_file"
ADD_CONTEXT "vendor" "bin/hw/vendor.samsung.hardware.vibrator-service" "hal_vibrator_default_exec"
LOG_INFO "Registered vibrator blobs in AstroROM context"

LOG_END "Vibration HAL fix applied successfully"
