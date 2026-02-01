#!/bin/bash
#
#  Copyright (c) 2025 Sameer Al Sahab
#  Licensed under the MIT License. See LICENSE file for details.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#

# [
#
# The following environment variables are automatically generated or consumed
# during device configuration generation.
#
# These variables describe hardware capabilities and firmware properties of
# the TARGET (stock) device.
#
# Unless explicitly overridden by a device configuration file, all values are
# detected automatically from the stock firmware and the given source firmware.
# If variables are already declared in config file, it will not overwrite them.
#

GENERATE_CONFIG()
{   # Format: "XML_TAG_NAME" or "XML_TAG_NAME:CUSTOM_VAR_SUFFIX"
    local FEATURE_CONFIG_MAP=(
        "LCD_CONFIG_HFR_MODE:DISPLAY_HFR_MODE"
        "COMMON_CONFIG_MDNIE_MODE:MDNIE_MODE"
        "LCD_SUPPORT_AMOLED_DISPLAY:HAVE_AMOLED_DISPLAY"
        "AUDIO_SUPPORT_DUAL_SPEAKER:HAVE_DUAL_SPEAKER"
        "LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE:DISPLAY_REFRESH_RATE_VALUES_HZ"
        "LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS:AUTO_BRIGHTNESS_LEVEL"
        "LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE:DEFAULT_REFRESH_RATE"
        "BIOAUTH_CONFIG_FINGERPRINT_FEATURES:FINGERPRINT_SENSOR_TYPE"
        "SETTINGS_CONFIG_BRAND_NAME:MODEL_NAME"
        "SYSTEM_CONFIG_SIOP_POLICY_FILENAME:SIOP_POLICY_FILENAME"
    )

    # Format: "partition:property_name:CUSTOM_VAR_SUFFIX"
    local PROPERTY_CONFIG_MAP=(
        "vendor:ro.vendor.build.version.release:FIRST_API_VERSION"
        "vendor:ro.vendor.build.version.sdk:FIRST_SDK_VERSION"
        "vendor:ro.vndk.version:VNDK_VERSION"
        "system:ro.product.system.device:SINGLE_SYSTEM_IMAGE"
    )

    # Format: "partition:path/to/file:CUSTOM_VAR_SUFFIX"
    local FILE_EXISTENCE_CONFIG_MAP=(
        "system:priv-app/AirCommand:HAVE_SPEN_SUPPORT"
        "system:priv-app/EsimKeyString:HAVE_ESIM_SUPPORT"
        "vendor:bin/hw/vendor.samsung.hardware.biometrics.face@2.0-service:HAVE_LEGACY_FACE_HAL"
    )

    local CONFIG_ENTRY PARTITION_NAME FEATURE_KEY VARIABLE_SUFFIX
    local SOURCE_VARIABLE_NAME DEVICE_VARIABLE_NAME
    local SOURCE_VALUE DEVICE_VALUE

    for CONFIG_ENTRY in "${FEATURE_CONFIG_MAP[@]}"; do
        FEATURE_KEY="${CONFIG_ENTRY%%:*}"
        VARIABLE_SUFFIX="${CONFIG_ENTRY#*:}"
        [[ "$CONFIG_ENTRY" != *":"* ]] && VARIABLE_SUFFIX="$FEATURE_KEY"

        SOURCE_VARIABLE_NAME="SOURCE_${VARIABLE_SUFFIX}"
        DEVICE_VARIABLE_NAME="DEVICE_${VARIABLE_SUFFIX}"

        if [[ -z "${!SOURCE_VARIABLE_NAME}" ]]; then
            SOURCE_VALUE=$(GET_FF_VAL "main" "$FEATURE_KEY")
            [[ "$SOURCE_VALUE" == "TRUE" ]] && SOURCE_VALUE="true"
            [[ "$SOURCE_VALUE" == "FALSE" ]] && SOURCE_VALUE="false"
            declare -g "$SOURCE_VARIABLE_NAME"="$SOURCE_VALUE"
        fi

        if [[ -z "${!DEVICE_VARIABLE_NAME}" ]]; then
            DEVICE_VALUE=$(GET_FF_VAL "stock" "$FEATURE_KEY")
            [[ "$DEVICE_VALUE" == "TRUE" ]] && DEVICE_VALUE="true"
            [[ "$DEVICE_VALUE" == "FALSE" ]] && DEVICE_VALUE="false"
            declare -g "$DEVICE_VARIABLE_NAME"="$DEVICE_VALUE"
        fi
    done

    for CONFIG_ENTRY in "${PROPERTY_CONFIG_MAP[@]}"; do
        PARTITION_NAME=$(echo "$CONFIG_ENTRY" | cut -d':' -f1)
        FEATURE_KEY=$(echo "$CONFIG_ENTRY" | cut -d':' -f2)
        VARIABLE_SUFFIX=$(echo "$CONFIG_ENTRY" | cut -d':' -f3)

        SOURCE_VARIABLE_NAME="SOURCE_${VARIABLE_SUFFIX}"
        DEVICE_VARIABLE_NAME="DEVICE_${VARIABLE_SUFFIX}"

        if [[ -z "${!SOURCE_VARIABLE_NAME}" ]]; then
            SOURCE_VALUE=$(GET_PROP "$PARTITION_NAME" "$FEATURE_KEY")
            declare -g "$SOURCE_VARIABLE_NAME"="$SOURCE_VALUE"
        fi

        if [[ -z "${!DEVICE_VARIABLE_NAME}" ]]; then
            DEVICE_VALUE=$(GET_PROP "$PARTITION_NAME" "$FEATURE_KEY" "stock")
            declare -g "$DEVICE_VARIABLE_NAME"="$DEVICE_VALUE"
        fi
    done

    for CONFIG_ENTRY in "${FILE_EXISTENCE_CONFIG_MAP[@]}"; do
        PARTITION_NAME="${CONFIG_ENTRY%%:*}"
        FEATURE_KEY="${CONFIG_ENTRY#*:}"
        FEATURE_KEY="${FEATURE_KEY%%:*}"
        VARIABLE_SUFFIX="${CONFIG_ENTRY##*:}"

        [[ "$CONFIG_ENTRY" != *":"* ]] && VARIABLE_SUFFIX="$FEATURE_KEY"

        SOURCE_VARIABLE_NAME="SOURCE_${VARIABLE_SUFFIX}"
        DEVICE_VARIABLE_NAME="DEVICE_${VARIABLE_SUFFIX}"

        if [[ -z "${!SOURCE_VARIABLE_NAME}" ]]; then
            if EXISTS "main" "$PARTITION_NAME" "$FEATURE_KEY"; then
                declare -g "$SOURCE_VARIABLE_NAME"="true"
            else
                declare -g "$SOURCE_VARIABLE_NAME"="false"
            fi
        fi

        if [[ -z "${!DEVICE_VARIABLE_NAME}" ]]; then
            if EXISTS "stock" "$PARTITION_NAME" "$FEATURE_KEY"; then
                declare -g "$DEVICE_VARIABLE_NAME"="true"
            else
                declare -g "$DEVICE_VARIABLE_NAME"="false"
            fi
        fi
    done

    if [[ -n "$DEVICE_ACTUAL_MODEL" ]]; then
        DEVICE_MODEL="$DEVICE_ACTUAL_MODEL"
    else
        DEVICE_MODEL="$STOCK_MODEL"
    fi

    export SEC_FLOATING_FEATURE_FILE="$WORKSPACE/system/system/etc/floating_feature.xml"
    export STOCK_SEC_FLOATING_FEATURE_FILE="$STOCK_FW/system/system/etc/floating_feature.xml"

    if [[ -z "${SOURCE_HAVE_QHD_PANEL+x}" ]]; then
        if grep -q "QHD" "$SEC_FLOATING_FEATURE_FILE"; then
            SOURCE_HAVE_QHD_PANEL=true
        else
            SOURCE_HAVE_QHD_PANEL=false
        fi
    fi

    if [[ -z "${DEVICE_HAVE_QHD_PANEL+x}" ]]; then
        if grep -q "QHD" "$STOCK_SEC_FLOATING_FEATURE_FILE"; then
            DEVICE_HAVE_QHD_PANEL=true
        else
            DEVICE_HAVE_QHD_PANEL=false
        fi
    fi

    if [[ -z "${DEVICE_HAVE_HIGH_REFRESH_RATE+x}" ]]; then
        if (( ${DEVICE_DISPLAY_HFR_MODE:-0} > 0 )); then
            DEVICE_HAVE_HIGH_REFRESH_RATE=true
        else
            DEVICE_HAVE_HIGH_REFRESH_RATE=false
        fi
    fi

# TODO : a way for check device has NPU or not. Usually flagship device have NPU related props in the xml.
# We use this method until a new way found. For example : dm3q
if [[ -z "${SOURCE_HAVE_NPU+x}" ]]; then
    if grep -q "NPU" "$SEC_FLOATING_FEATURE_FILE"; then
        SOURCE_HAVE_NPU=true
    else
        SOURCE_HAVE_NPU=false
    fi
fi

if [[ -z "${DEVICE_HAVE_NPU+x}" ]]; then
    if grep -q "NPU" "$STOCK_SEC_FLOATING_FEATURE_FILE"; then
        DEVICE_HAVE_NPU=true
    else
        DEVICE_HAVE_NPU=false
    fi
fi

DEVICE_USE_STOCK_BASE=false

if [ "$STOCK_MODEL" = "$MODEL" ]; then
    DEVICE_USE_STOCK_BASE=true
fi

    LOG_INFO "Automatic generated config:"

    for VARIABLE_NAME in $(compgen -v DEVICE_ | sort); do
        printf '  %s=%s\n' "$VARIABLE_NAME" "${!VARIABLE_NAME}"
    done
}


# ============================================================================
#
#   DEVICE_DISPLAY_HFR_MODE
#     Integer describing the display High Frame Rate (HFR) mode supported
#     by the device panel.
#
#     A value greater than zero indicates that the display supports refresh
#     rates higher than 60Hz (e.g. 90Hz, 120Hz, or adaptive).
#
#     This value is usually read from floating_feature.xml and serves as the
#     base indicator for high refresh rate capability.
#
#
#   DEVICE_HAVE_HIGH_REFRESH_RATE
#     Boolean flag derived from DEVICE_DISPLAY_HFR_MODE.
#
#     Set to true when DEVICE_DISPLAY_HFR_MODE is greater than zero,
#     indicating that the device supports smooth / high refresh rate modes.
#
#     This variable is commonly used to enable or disable display-related
#     features such as adaptive refresh rate, smooth animations.
#
#
#   DEVICE_DISPLAY_REFRESH_RATE_VALUES_HZ
#     String containing a comma-separated list of refresh rates (in Hz)
#     supported by the device display.
#
#
#   DEVICE_DEFAULT_REFRESH_RATE
#     Integer specifying the default refresh rate (in Hz) selected by the
#     system at boot or after a factory reset.
#
#     This value does not restrict the maximum refresh rate but defines the
#     initial operating mode of the display.
#
#
#   DEVICE_HAVE_QHD_PANEL
#     Boolean flag indicating whether the device uses a QHD (1440p) display
#     panel.
#
#     The value is determined by scanning the stock floating_feature.xml
#     for QHD-related configuration entries.
#
#     This variable is used to adjust rendering scale, performance profiles,
#     and resolution-dependent system behavior.
#
#
#   DEVICE_HAVE_AMOLED_DISPLAY
#     Boolean flag indicating whether the device is equipped with an AMOLED
#     or OLED display panel.
#
#     This flag affects display color calibration, power optimizations, and
#     feature availability such as Always-On Display.
#
#
#   DEVICE_HAVE_DUAL_SPEAKER
#     Boolean flag describing the audio speaker configuration of the device.
#
#     Set to true when the device features a dual-speaker (stereo) setup,
#     otherwise false for single-speaker (mono) configurations.
#
#     Used by audio services and sound effect frameworks.
#
#
#   DEVICE_AUTO_BRIGHTNESS_LEVEL
#     Integer or enumerated value describing the auto-brightness control
#     behavior supported by the device.
#
#     This variable influences how the system reacts to ambient light
#     changes via sensor-based brightness adjustment.
#
#
#   DEVICE_HAVE_SPEN_SUPPORT
#     Boolean flag indicating Samsung S-Pen support.
#
#     Detection is based on the presence of the AirCommand system application
#     in the stock firmware.
#
#     When set to true, stylus-related frameworks and features are enabled.
#
#
#   DEVICE_HAVE_ESIM_SUPPORT
#     Boolean flag indicating embedded SIM (eSIM) support on the device.
#
#     Detection is based on the presence of eSIM-related system components
#     in the stock firmware.
#
#     When false, the device is assumed to support physical SIM cards only.
#
#
#   DEVICE_ANDROID_VERSION
#     String containing the Android version of the stock device firmware.
#
#   DEVICE_HAVE_NPU
#     Boolean flag indicating the presence of a dedicated Neural Processing
#     Unit (NPU) on the device.
#
#
#   DEVICE_SDK_VERSION
#     Integer containing the Android SDK (API) level of the stock firmware.
#
#
#   DEVICE_VNDK_VERSION
#     Integer or string identifying the Vendor Native Development Kit (VNDK)
#     version used by the stock firmware.
#
#     This value is critical for maintaining compatibility between system
#     and vendor partitions under Project Treble.
#
# ============================================================================
# ]
