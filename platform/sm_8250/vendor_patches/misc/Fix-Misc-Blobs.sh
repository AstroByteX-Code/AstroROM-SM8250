# ==============================================================================
# Patch: Fix Random Reboot (AstroROM style)
# Context:
#   - Removes unstable TLC ICCC HAL/service blobs
#   - Injects stable blobs from y2q firmware
#   - Ensures system stability and prevents reboot loops
# ==============================================================================

LOG_BEGIN "Fixing Random Reboot..."

# Remove unstable TLC ICCC HAL/service blobs
SILENT REMOVE "vendor" "lib64/vendor.samsung.hardware.tlc.iccc@1.0.so"
SILENT REMOVE "vendor" "bin/hw/vendor.samsung.hardware.tlc.iccc@1.0-service"
SILENT REMOVE "vendor" "etc/init/vendor.samsung.hardware.tlc.iccc@1.0-service.rc"
SILENT REMOVE "vendor" "lib64/vendor.samsung.hardware.tlc.iccc@1.0-impl.so"
LOG_INFO "Removed unstable TLC ICCC HAL/service blobs"

# Inject stable TLC ICCC HAL/service blobs from y2q firmware
ADD_FROM_FW "y2q" "vendor" "lib64/vendor.samsung.hardware.tlc.iccc@1.0.so"
ADD_FROM_FW "y2q" "vendor" "bin/hw/vendor.samsung.hardware.tlc.iccc@1.0-service"
ADD_FROM_FW "y2q" "vendor" "etc/init/vendor.samsung.hardware.tlc.iccc@1.0-service.rc"
ADD_FROM_FW "y2q" "vendor" "lib64/vendor.samsung.hardware.tlc.iccc@1.0-impl.so"
LOG_INFO "Injected stable TLC ICCC HAL/service blobs from y2q firmware"

LOG_END "Random Reboot fix applied successfully"
