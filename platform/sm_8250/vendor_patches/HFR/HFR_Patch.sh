# ==============================================================================
# HFR patch (AstroROM style)
# ==============================================================================

LOG_BEGIN "- Adding a73 MIDAS"
SILENT REMOVE "vendor" "etc/midas"
ADD_FROM_FW "a73" "vendor" "etc/midas"
LOG_END

LOG_BEGIN "- Setting Adaptive HFR flags"
BPROP "vendor" "debug.sf.show_refresh_rate_overlay_render_rate" "true"
BPROP "vendor" "ro.surface_flinger.game_default_frame_rate_override" "60"
BPROP "vendor" "ro.surface_flinger.use_content_detection_for_refresh_rate" "true"
BPROP "vendor" "ro.surface_flinger.set_idle_timer_ms" "250"
BPROP "vendor" "ro.surface_flinger.set_touch_timer_ms" "300"
BPROP "vendor" "ro.surface_flinger.set_display_power_timer_ms" "200"
BPROP "vendor" "ro.surface_flinger.enable_frame_rate_override" "true"
LOG_END

LOG_BEGIN "- Removing configstore-1.1 service"
SILENT REMOVE "vendor" "bin/hw/android.hardware.configstore@1.1-service"
SILENT REMOVE "vendor" "etc/init/android.hardware.configstore@1.1-service.rc"
SILENT REMOVE "vendor" "etc/seccomp_policy/configstore@1.1.policy"
LOG_END
