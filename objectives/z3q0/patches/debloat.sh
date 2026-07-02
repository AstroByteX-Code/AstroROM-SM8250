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

# system_ext clean-up
SILENT REMOVE "system" "etc/permissions/org.carconnectivity.android.digitalkey.rangingintent.xml"	
SILENT REMOVE "system" "etc/permissions/org.carconnectivity.android.digitalkey.secureelement.xml"

BLOAT_TARGETS+=(
    "QCC"
	"com.qualcomm.location"
	"com.qualcomm.qti.services.systemhelper"
)

SILENT REMOVE "system" "system_ext/bin/qccsyshal@1.2-service"
SILENT REMOVE "system" "system_ext/etc/init/vendor.qti.hardware.qccsyshal@1.2-service.rc"
SILENT REMOVE "system" "system_ext/etc/permissions/com.qti.location.sdk.xml"
SILENT REMOVE "system" "system_ext/etc/permissions/com.qualcomm.location.xml"
SILENT REMOVE "system" "system_ext/etc/permissions/privapp-permissions-com.qualcomm.location.xml"

LOG_END "Debloated successfully"
