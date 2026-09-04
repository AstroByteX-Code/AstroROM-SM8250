# ==============================================================================
# Patch: Fix Brightness HAL (AstroROM style)
# Context:
#   - Removes outdated light HAL/service stubs
#   - Injects stable blobs from y2q firmware
#   - Ensures proper brightness control and light service stability
# ==============================================================================

LOG_BEGIN "Fixing Brightness HAL..."

# Remove old light HAL/service stubs
SILENT REMOVE "vendor" "bin/hw/vendor.samsung.hardware.light-service"
SILENT REMOVE "vendor" "lib64/vendor.samsung.hardware.light-V1-ndk_platform.so"
SILENT REMOVE "vendor" "lights.kona.so"
LOG_INFO "Removed outdated light HAL and service binaries"

# Inject stable light HAL blobs from y2q firmware
ADD_FROM_FW "y2q" "vendor" "bin/hw/vendor.samsung.hardware.light-service"
ADD_FROM_FW "y2q" "vendor" "lib64/vendor.samsung.hardware.light-V1-ndk_platform.so"
ADD_FROM_FW "y2q" "vendor" "lib64/lights.kona.so"
LOG_INFO "Injected light HAL and service binaries from y2q firmware"

LOG_END "Brightness HAL fix applied successfully"
