# ADD GameDriver
ADD_FROM_FW "stock" "system" "priv-app/GameDriver-SM8250"

ADD_FROM_FW "stock" "system" "etc/init/rscmgr.rc"

#Light Sensor App
ADD_FROM_FW "y2q" "system" "etc/permissions/privapp-permissions-com.samsung.adaptivebrightnessgo.cameralightsensor.xml"
ADD_FROM_FW "y2q" "system" "priv-app/CameraLightSensor"

#Lux Map config
ADD_FROM_FW "stock" "system" "etc/ev_lux_map_config.xml"

#Camera Blobs
SILENT NUKE_BLOAT "system" "priv-app/SamsungCamera"
SILENT NUKE_BLOAT "system" "priv-app/PhotoRemasterService"
ADD_FROM_FW "a73" "system" "priv-app/SamsungCamera"
ADD_FROM_FW "a73" "system" "priv-app/PhotoRemasterService"

# ADD 32bit WFD
SILENT REMOVE "system" "bin/insthk"
SILENT REMOVE "system" "bin/remotedisplay"
SILENT REMOVE "system" "lib64/libhdcp_client_aidl.so"
SILENT REMOVE "system" "lib64/libhdcp2.so"
SILENT REMOVE "system" "lib64/libremotedisplay_wfd.so"
SILENT REMOVE "system" "lib64/libremotedisplayservice.so"
SILENT REMOVE "system" "lib64/libsecuibc.so"
SILENT REMOVE "system" "lib64/libstagefright_hdcp.so"
SILENT REMOVE "system" "lib64/vendor.samsung.hardware.security.hdcp.wifidisplay-V2-ndk.so"
SILENT REMOVE "system" "lib64/wfd_log.so"

ADD_FROM_FW "r9q" "system" "bin/insthk"
ADD_FROM_FW "r9q" "system" "bin/remotedisplay"
ADD_FROM_FW "r9q" "system" "lib/libhdcp2.so"
ADD_FROM_FW "r9q" "system" "lib/libremotedisplayservice.so"
ADD_FROM_FW "r9q" "system" "lib/libremotedisplay_wfd.so"
ADD_FROM_FW "r9q" "system" "lib/libsecuibc.so"
ADD_FROM_FW "r9q" "system" "lib/libstagefright_hdcp.so"
ADD_FROM_FW "r9q" "system" "lib/wfd_log.so"

ADD_CONTEXT "system" "bin/insthk" "system_file"
ADD_CONTEXT "system" "bin/remotedisplay" "system_file"
ADD_CONTEXT "system" "lib/libhdcp2.so" "system_file"
ADD_CONTEXT "system" "lib/libremotedisplayservice.so" "system_file"
ADD_CONTEXT "system" "lib/libremotedisplay_wfd.so" "system_file"
ADD_CONTEXT "system" "lib/libsecuibc.so" "system_file"
ADD_CONTEXT "system" "lib/libstagefright_hdcp.so" "system_file"
ADD_CONTEXT "system" "lib/wfd_log.so" "system_file"

# Add Stock Google blobs
NUKE_BLOAT "product" "priv-app/HotwordEnrollmentOKGoogleEx4HEXAGON"
NUKE_BLOAT "product" "priv-app/HotwordEnrollmentXGoogleEx4HEXAGON"

ADD_FROM_FW "dm3q" "product" "priv-app/HotwordEnrollmentOKGoogleEx3HEXAGON"
ADD_FROM_FW "dm3q" "product" "priv-app/HotwordEnrollmentXGoogleEx3HEXAGON"

SILENT REMOVE "system" "etc/permissions/com.sec.feature.cover.clearcameraviewcover.xml"
SILENT REMOVE "system" "etc/permissions/com.sec.feature.cover.flip.xml"
SILENT REMOVE "system" "etc/permissions/com.sec.feature.pocketsensitivitymode_level1.xml"

ADD_FROM_FW "stock" "system" "etc/permissions/com.sec.feature.cover.clearsideviewcover.xml"

ADD_FROM_FW "stock" "system" "priv-app/DesktopSystemUI"

# Add stock TUI app
ADD_FROM_FW "y2q" "system" "system_ext/app/com.qualcomm.qti.services.secureui"
ADD_FROM_FW "y2q" "system" "etc/sysconfig/preinstalled-packages-com.qualcomm.qti.services.secureui.xml"

# Add a73 libhwui
ADD_FROM_FW "a73" "system" "lib/libhwui.so"
ADD_FROM_FW "a73" "system" "lib64/libhwui.so"

# Adding a73 keymaster libs
SILENT REMOVE "system" "lib/android.hardware.security.keymint-V2-ndk.so"
SILENT REMOVE "system" "lib/android.hardware.security.secureclock-V1-ndk.so"
SILENT REMOVE "system" "lib/libdk_native_keymint.so"
SILENT REMOVE "system" "lib/vendor.samsung.hardware.keymint-V2-ndk.so"
SILENT REMOVE "system" "lib64/android.hardware.security.keymint-V2-ndk.so"
SILENT REMOVE "system" "lib64/libdk_native_keymint.so"
SILENT REMOVE "system" "lib64/vendor.samsung.hardware.keymint-V2-ndk.so"
ADD_FROM_FW "a73" "system" "lib/android.hardware.keymaster@3.0.so"
ADD_FROM_FW "a73" "system" "lib/android.hardware.keymaster@4.0.so"
ADD_FROM_FW "a73" "system" "lib/android.hardware.keymaster@4.1.so"
ADD_FROM_FW "a73" "system" "lib/lib_nativeJni.dk.samsung.so"
ADD_FROM_FW "a73" "system" "lib/libdk_native_keymaster.so"
ADD_FROM_FW "a73" "system" "lib/libkeymaster4_1support.so"
ADD_FROM_FW "a73" "system" "lib/libkeymaster4support.so"
ADD_FROM_FW "a73" "system" "lib64/lib_nativeJni.dk.samsung.so"
ADD_FROM_FW "a73" "system" "lib64/libdk_native_keymaster.so"

# Fixing MIDAS, AI and camera
ADD_FROM_FW "a73" "system" "etc/public.libraries-camera.samsung.txt"
ADD_FROM_FW "a73" "system" "lib64/libSlowShutter_jni.media.samsung.so"
ADD_FROM_FW "a73" "system" "lib64/lib_nativeJni.dk.samsung.so"
ADD_FROM_FW "a73" "system" "lib64/libmidas_DNNInterface.camera.samsung.so"
ADD_FROM_FW "a73" "system" "lib64/libmidas_core.camera.samsung.so"
ADD_FROM_FW "a73" "system" "lib64/libsamsung_videoengine_9_0.so"
ADD_FROM_FW "a73" "system" "lib64/libtensorflowLite.camera.samsung.so"
ADD_FROM_FW "a73" "system" "lib64/libtensorflowlite_inference_api.camera.samsung.so"

# Adding pa1q nfc blobs
SILENT REMOVE "system" "lib64/libnfc_nxpsn_jni.so"
ADD_FROM_FW "pa1q" "system" "lib64/libnfc_sec_jni.so"
ADD_FROM_FW "pa1q" "system" "lib64/libnfc-nci_flags.so"
ADD_FROM_FW "pa1q" "system" "lib64/libnfc-sec.so"
ADD_FROM_FW "pa1q" "system" "lib64/libstatslog_nfc.so"

ADD_FROM_FW "stock" "system" "etc/permissions/com.sec.feature.cover.clearsideviewcover.xml"
ADD_FROM_FW "stock" "system" "etc/permissions/com.sec.feature.cover.xml"
ADD_FROM_FW "stock" "system" "etc/permissions/com.sec.feature.cover.sview.xml"
ADD_FROM_FW "stock" "system" "etc/permissions/com.sec.feature.nfc_authentication_cover.xml"
