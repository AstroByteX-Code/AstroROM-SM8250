#!/bin/bash

REFRESH_RATE_CONFIG_SMALI=$(find . -type f -path "*/com/samsung/android/hardware/display/RefreshRateConfig.smali" | head -n 1)

# If the class isn't found, skip gracefully
if [ -z "$REFRESH_RATE_CONFIG_SMALI" ]; then
    LOG_WARN "RefreshRateConfig.smali not found; skipping brightness threshold patch (patches/Remove-BrightnessThreshold.sh)"
    exit 0
fi

# --- Remove SEAMLESS_BRT threshold ---
if grep -q 'const-string v0, "SEAMLESS_BRT: 35"' "$REFRESH_RATE_CONFIG_SMALI"; then
    REPLACE_LINE \
        'const-string v0, "SEAMLESS_BRT: 35"' \
        'const-string v0, "SEAMLESS_BRT: "' \
        "$REFRESH_RATE_CONFIG_SMALI"
    LOG_INFO "Patched RefreshRateConfig: removed SEAMLESS_BRT threshold (35 → empty)"
fi

# --- Remove SEAMLESS_LUX threshold ---
if grep -q 'const-string v0, "SEAMLESS_LUX: 40"' "$REFRESH_RATE_CONFIG_SMALI"; then
    REPLACE_LINE \
        'const-string v0, "SEAMLESS_LUX: 40"' \
        'const-string v0, "SEAMLESS_LUX: "' \
        "$REFRESH_RATE_CONFIG_SMALI"
    LOG_INFO "Patched RefreshRateConfig: removed SEAMLESS_LUX threshold (40 → empty)"
fi

# --- Adjust locals count ---
if grep -q '.locals 5' "$REFRESH_RATE_CONFIG_SMALI"; then
    REPLACE_LINE \
        '.locals 5' \
        '.locals 4' \
        "$REFRESH_RATE_CONFIG_SMALI"
    LOG_INFO "Patched RefreshRateConfig: adjusted .locals (5 → 4)"
fi

# --- Clear brightness threshold strings ---
if grep -q 'const-string v3, "35"' "$REFRESH_RATE_CONFIG_SMALI"; then
    REPLACE_LINE \
        'const-string v3, "35"' \
        'const-string v3, ""' \
        "$REFRESH_RATE_CONFIG_SMALI"
    LOG_INFO "Patched RefreshRateConfig: cleared v3 threshold string"
fi

if grep -q 'const-string v4, "40"' "$REFRESH_RATE_CONFIG_SMALI"; then
    REPLACE_LINE \
        'const-string v4, "40"' \
        'const-string v4, ""' \
        "$REFRESH_RATE_CONFIG_SMALI"
    LOG_INFO "Patched RefreshRateConfig: cleared v4 threshold string"
fi

# --- Update constructor call ---
if grep -q 'invoke-direct {v0, v3, v4, v1, v2}, Lcom/samsung/android/hardware/display/RefreshRateConfig$BrightnessThreshold;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V' "$REFRESH_RATE_CONFIG_SMALI"; then
    REPLACE_LINE \
        'invoke-direct {v0, v3, v4, v1, v2}, Lcom/samsung/android/hardware/display/RefreshRateConfig$BrightnessThreshold;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V' \
        'invoke-direct {v0, v3, v3, v1, v2}, Lcom/samsung/android/hardware/display/RefreshRateConfig$BrightnessThreshold;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V' \
        "$REFRESH_RATE_CONFIG_SMALI"
    LOG_INFO "Patched RefreshRateConfig: updated BrightnessThreshold constructor (v3,v4 → v3,v3)"
fi
