# ==============================================================================
# Patch: AppLock Support
# Context:
#   - Adds AppLock APK and permissions from e1q firmware
#   - Registers context for proper packaging and HAL execution
# ==============================================================================

LOG_BEGIN "Adding AppLock support from e1q..."

# Inject AppLock APK and permissions
ADD_FROM_FW "e1q" "system" "priv-app/AppLock/AppLock.apk"
ADD_FROM_FW "e1q" "system" "etc/permissions/privapp-permissions-com.samsung.android.applock.xml"
LOG_INFO "Injected AppLock APK and permissions from e1q firmware"

# Register context for AppLock files
ADD_CONTEXT "system" "priv-app/AppLock/AppLock.apk" "system_file"
ADD_CONTEXT "system" "etc/permissions/privapp-permissions-com.samsung.android.applock.xml" "system_file"
LOG_INFO "Registered AppLock files in AstroROM context"

LOG_END "AppLock patch applied successfully"
