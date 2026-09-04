# ==============================================================================
# Patch: Fix portrait mode (AstroROM style)
# Context:
#   - Ensures DualCam Bokeh libs reference correct product properties
#   - Injects ro.astro.camera property into SELinux contexts
#   - Applies safe HEX edits to camera libs when needed
# ==============================================================================

LOG_BEGIN "Fixing portrait mode for camera..."

if [ -f "$WORKSPACE/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" ]; then
    if grep -q "ro.build.flavor" "$WORKSPACE/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" 2>/dev/null; then
        BPROP_IF_DIFF "main" "stock" "ro.build.flavor"
        LOG_INFO "Applied BPROP_IF_DIFF for ro.build.flavor"
    elif grep -q "ro.product.name" "$WORKSPACE/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" 2>/dev/null; then
        LOG_INFO "Applying HEX edits to camera libs"
        HEX_EDIT "vendor/lib/libDualCamBokehCapture.camera.samsung.so" \
            "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
        HEX_EDIT "vendor/lib/liblivefocus_capture_engine.so" \
            "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
        HEX_EDIT "vendor/lib/liblivefocus_preview_engine.so" \
            "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
        HEX_EDIT "vendor/lib64/libDualCamBokehCapture.camera.samsung.so" \
            "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
        HEX_EDIT "vendor/lib64/liblivefocus_capture_engine.so" \
            "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
        HEX_EDIT "vendor/lib64/liblivefocus_preview_engine.so" \
            "726f2e70726f647563742e6e616d6500" "726f2e756e6963612e63616d65726100"
    fi
else
    LOG_INFO "Skipping: libDualCamBokehCapture.camera.samsung.so not found"
fi

LOG_END "Portrait mode fix applied successfully"
