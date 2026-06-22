# ==============================================================================
#
# MOD_NAME="Debloat useless apps"
# MOD_AUTHOR="ShaDisNX255"
# MOD_DESC="Debloats non needed apps and files from ROM."
#
# ==============================================================================


#  OVERLAYS
BLOAT_TARGETS+=(
    "WifiRROverlayAppH2E"
	"WifiRROverlayAppQC"
	"WifiRROverlayAppWifiLock"
	"SoftapOverlay6GHz"
	"SoftapOverlayDualAp"
	"SoftapOverlayOWE"
)

SILENT REMOVE "system" "bin/mafpc_write"

BLOAT_TARGETS+=(
    "GlobalPostProcMgr"
	"PetService"
	"VideoScan"
	"SohService"
)

SILENT REMOVE "system" "etc/default-permissions/default-permissions-com.samsung.android.globalpostprocmgr.xml"
SILENT REMOVE "system" "etc/default-permissions/default-permissions-com.samsung.petservice.xml"
SILENT REMOVE "system" "etc/default-permissions/default-permissions-com.samsung.videoscan.xml"
SILENT REMOVE "system" "etc/permissions/privapp-permissions-com.samsung.android.globalpostprocmgr.xml"	
SILENT REMOVE "system" "etc/permissions/privapp-permissions-com.samsung.petservice.xml"
SILENT REMOVE "system" "etc/permissions/privapp-permissions-com.samsung.videoscan.xml"

LOG_END "Debloated successfully"
