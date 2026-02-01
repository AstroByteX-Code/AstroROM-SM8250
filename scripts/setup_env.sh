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
DEPENDENCY_CONFIG=(
    "openjdk-17-jdk|jdk17-openjdk|Java 17+ (Java is required for APK/JAR patching)|true"
    "python3|python|Python 3 (For Python modules)|true"
    "xmlstarlet|xmlstarlet|xmlstarlet for editing xml files|true"
    "lz4|lz4|LZ4 for decompress and compress|true"
    "p7zip-full|p7zip|7-Zip for extraction and compress|true"
    "bc|bc|BC calculator for size calculations|true"
    "zip|zip|Zip utility for zipping|true"
    "e2fsprogs|e2fsprogs|e2fsprogs for ext4 filesystem tools|true"
    "attr|attr|xattr for selinux configs|true"
    "zipalign|android-sdk-build-tools|zipalign for APKs alignment|true"
    "f2fs-tools|f2fs-tools|f2fs-tools for f2fs filesystem|true"
    "nodejs|nodejs|Node.js for JS-based works|true"
    "jq|jq|jq for jq based usages|true"
    "ffmpeg|ffmpeg|ffmpeg for video compress and conversion|true"
    "webp|libwebp-utils|webp for compressing images|true"
    "acl|acl|acl for granting regular user permissions|true"
)

DETECTED_DISTRO_TYPE=""

VALIDATE_DEVICE_VARS()
{
    local MISSING_VARIABLES=()
    local ERROR_MESSAGES=(
        ["CODENAME"]="A specific device codename must be defined."
        ["MODEL"]="The main firmware model identifier (\$MODEL)."
        ["STOCK_MODEL"]="The target stock firmware model identifier (\$STOCK_MODEL)."
        ["FILESYSTEM"]="The desired target filesystem type (\$FILESYSTEM) must needed for repack images"
    )

    for VARIABLE_NAME in "${!ERROR_MESSAGES[@]}"; do
        if [[ -z "${!VARIABLE_NAME}" ]]; then
            MISSING_VARIABLES+=("$VARIABLE_NAME:${ERROR_MESSAGES[$VARIABLE_NAME]}")
        fi
    done

    if [[ ${#MISSING_VARIABLES[@]} -gt 0 ]]; then
        LOG "Cannot continue. Missing required environment variables:"
        for VARIABLE_ENTRY in "${MISSING_VARIABLES[@]}"; do
            IFS=':' read -r VARIABLE_NAME ERROR_MESSAGE <<< "$VARIABLE_ENTRY"
            echo -e "  ${COLOR_RED}✗${COLOR_RESET} ${VARIABLE_NAME}: ${ERROR_MESSAGE}"
        done
        echo
        ERROR_EXIT "Critical configuration parameters are not given. Aborting build environment."
        return 1
    fi

    return 0
}

SETUP_DEVICE_ENV()
{
    LOG_BEGIN "Setting up Device environment"

    if ! VALIDATE_DEVICE_VARS; then
        LOG_WARN "Failed to validate device environment variables."
        return 1
    fi

    echo -e "  ${COLOR_BLUE}DEVICE INFO:${COLOR_RESET}"
    echo -e "    → Device:               ${TEXT_BOLD}${MODEL_NAME}${COLOR_RESET}"
    echo -e "    → Codename:             ${TEXT_BOLD}${CODENAME}${COLOR_RESET}"
    echo -e "    → Stock Model:          ${TEXT_BOLD}${STOCK_MODEL}${COLOR_RESET}"
    echo -e
    echo -e "    → Source Model:         ${TEXT_BOLD}${MODEL}${COLOR_RESET}"
    echo -e "    → Extra Model:          ${EXTRA_MODEL:-[None]}"
    echo -e
    echo -e "  ${COLOR_BLUE}BUILD PARAMETERS:${COLOR_RESET}"
    echo -e "    → Target Filesystem:    ${FILESYSTEM}"
    echo -e "    → Debug Mode:           ${DEBUG_BUILD}"
    echo -e ""

    if ! IS_GITHUB_ACTIONS; then
        echo -e "Imported config. Press ${COLOR_GREEN}ENTER${COLOR_RESET} to proceed with the build, or ${COLOR_RED}Ctrl+C${COLOR_RESET} to abort."
        read -r USER_CONFIRMATION
    else
        LOG_INFO "CI environment detected, proceeding with build automatically."
    fi

    INIT_BUILD_ENV
}

GET_DISTRO_TYPE()
{
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "arch" || "$ID_LIKE" == "arch" ]]; then
            echo "arch"
            return
        elif [[ "$ID" == "debian" || "$ID_LIKE" == "debian" || "$ID" == "ubuntu" || "$ID_LIKE" == "ubuntu" ]]; then
            echo "debian"
            return
        fi
    fi

    if command -v pacman &>/dev/null; then
        echo "arch"
    elif command -v dpkg &>/dev/null; then
        echo "debian"
    else
        echo "unknown"
    fi
}

CHECK_ALL_DEPENDENCIES()
{
    if find "$PREBUILTS" -type f ! -executable | grep -q .; then
        find "$PREBUILTS" -type f ! -executable -exec chmod +x {} + 2>/dev/null || true
    fi

    DETECTED_DISTRO_TYPE=$(GET_DISTRO_TYPE)

    if [[ "$DETECTED_DISTRO_TYPE" == "unknown" ]]; then
        ERROR_EXIT "Unsupported operating system. Cannot auto-install dependencies."
    fi

    LOG_BEGIN "System is $DETECTED_DISTRO_TYPE. Verifying dependencies..."

    local ALL_PACKAGES_INSTALLED=true
    local PACKAGE_CONFIG_STRING PACKAGE_DISPLAY_NAME DEBIAN_PACKAGE_NAME ARCH_PACKAGE_NAME RESOLVED_PACKAGE_NAME IS_CRITICAL_PACKAGE

    if [[ "$DETECTED_DISTRO_TYPE" == "debian" ]]; then
        sudo apt-get update &>/dev/null
    fi

    for PACKAGE_CONFIG_STRING in "${DEPENDENCY_CONFIG[@]}"; do
        IFS='|' read -r DEBIAN_PACKAGE_NAME ARCH_PACKAGE_NAME PACKAGE_DISPLAY_NAME IS_CRITICAL_PACKAGE <<< "$PACKAGE_CONFIG_STRING"

        if [[ "$DETECTED_DISTRO_TYPE" == "arch" ]]; then
            RESOLVED_PACKAGE_NAME="$ARCH_PACKAGE_NAME"
        else
            RESOLVED_PACKAGE_NAME="$DEBIAN_PACKAGE_NAME"
        fi

        if ! CHECK_DEPENDENCY "$RESOLVED_PACKAGE_NAME" "$PACKAGE_DISPLAY_NAME" "$IS_CRITICAL_PACKAGE"; then
            if [[ "$IS_CRITICAL_PACKAGE" == "true" ]]; then
                ALL_PACKAGES_INSTALLED=false
            fi
        fi
    done

    if "$ALL_PACKAGES_INSTALLED"; then
        LOG_END "All dependencies are installed and ready."
    else
        ERROR_EXIT "Critical dependencies failed to install. Check your internet or package manager."
    fi
}

CHECK_DEPENDENCY()
{
    local PACKAGE_NAME="$1"
    local PACKAGE_DISPLAY_NAME="${2:-$PACKAGE_NAME}"
    local IS_CRITICAL_PACKAGE="${3:-false}"

    if [[ "$DETECTED_DISTRO_TYPE" == "arch" ]]; then
        pacman -Q "$PACKAGE_NAME" &>/dev/null && return 0
    else
        dpkg -s "$PACKAGE_NAME" &>/dev/null && return 0
    fi

    LOG_BEGIN "Installing  $PACKAGE_DISPLAY_NAME..."
    local INSTALLATION_SUCCESSFUL=false

    if [[ "$DETECTED_DISTRO_TYPE" == "arch" ]]; then
        if sudo pacman -S --noconfirm --needed "$PACKAGE_NAME" &>/dev/null; then
            INSTALLATION_SUCCESSFUL=true
        else
            if ! command -v yay &>/dev/null; then
                sudo pacman -S --noconfirm yay
            fi

            if sudo -u "$(logname)" yay -S --noconfirm --needed --answerclean None --answerdiff None "$PACKAGE_NAME" &>/dev/null; then
                INSTALLATION_SUCCESSFUL=true
            fi
        fi

    elif [[ "$DETECTED_DISTRO_TYPE" == "debian" ]]; then
        if sudo apt-get install -y "$PACKAGE_NAME" &>/dev/null; then
            INSTALLATION_SUCCESSFUL=true
        fi
    fi

    if $INSTALLATION_SUCCESSFUL; then
        return 0
    else
        if [[ "$IS_CRITICAL_PACKAGE" == "true" ]]; then
            ERROR_EXIT "Failed to install required dependency: $PACKAGE_DISPLAY_NAME ($PACKAGE_NAME)"
        else
            LOG_WARN "Failed to install optional dependency: $PACKAGE_DISPLAY_NAME"
            return 1
        fi
    fi
}
# ]
