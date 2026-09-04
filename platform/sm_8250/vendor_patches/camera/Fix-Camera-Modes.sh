# ==============================================================================
# Patch: Fix Night Mode crash + Single Take Video Mode (AstroROM style)
# Context:
#   - Removes outdated SwISP libs causing Night Mode crash
#   - Injects stable SwISP libs from stock firmware
#   - Restores Single Take video mode configs from dm3q firmware
#   - Ensures gallery AI expansion features are enabled
# ==============================================================================

LOG_BEGIN "Fixing Night Mode crash..."

# Remove old SwISP libs
SILENT REMOVE "system" "lib64/libSwIsp_wrapper_v1.camera.samsung.so"
SILENT REMOVE "system" "lib64/libSwIsp_core.camera.samsung.so"
LOG_INFO "Removed outdated SwISP wrapper/core libs"

# Inject stable SwISP libs from stock firmware
ADD_FROM_FW "stock" "system" "lib64/libSwIsp_wrapper_v1.camera.samsung.so"
ADD_FROM_FW "stock" "system" "lib64/libSwIsp_core.camera.samsung.so"
LOG_INFO "Injected SwISP wrapper/core libs from stock firmware"

LOG_END "Night Mode crash fix applied successfully"

LOG_BEGIN "Fixing Single Take Video Mode..."

# Replace Single Take configs
REMOVE "vendor" "etc/singletake"
ADD_FROM_FW "dm3q" "vendor" "etc/singletake"
LOG_INFO "Replaced Single Take configs from dm3q firmware"

# Enable AI expansion features
FF "GALLERY_CONFIG_AI_EXPANSION" "AI_Timelapse"
LOG_INFO "Enabled AI Timelapse expansion in gallery config"

# Replace SwISP 1.0 configs
REMOVE "vendor" "saiv/swisp_1.0"
ADD_FROM_FW "dm3q" "vendor" "saiv/swisp_1.0"
LOG_INFO "Replaced SwISP 1.0 configs from dm3q firmware"

LOG_END "Single Take Video Mode fix applied successfully"
