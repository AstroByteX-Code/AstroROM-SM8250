# ==============================================================================
# Author: "Code_by_Mian"
# Patch: Astro Kernel Download
# Context:
#   - Downloads latest Astro kernel boot and dtbo images to the build output
# ==============================================================================

KERNEL_REPO="https://github.com/AstroByteX-Code/kernel_samsung_y2q/releases/latest/download"
KERNEL_OUT="$DIROUT"

LOG_BEGIN "Downloading Astro kernel..."

COMMAND_EXISTS wget || ERROR_EXIT "wget is required to download the Astro kernel"
mkdir -p "$KERNEL_OUT" || ERROR_EXIT "Cannot create kernel output directory: $KERNEL_OUT"

DOWNLOAD_KERNEL_IMAGE()
{
    local IMAGE_NAME="$1"
    local TARGET="$KERNEL_OUT/$IMAGE_NAME"
    local TEMP_TARGET="${TARGET}.tmp.$$"

    rm -f "$TEMP_TARGET"
    wget -O "$TEMP_TARGET" "$KERNEL_REPO/$IMAGE_NAME" || {
        rm -f "$TEMP_TARGET"
        ERROR_EXIT "Failed to download $IMAGE_NAME from Astro kernel repo"
    }

    [[ -s "$TEMP_TARGET" ]] || {
        rm -f "$TEMP_TARGET"
        ERROR_EXIT "Downloaded $IMAGE_NAME is empty"
    }

    mv -f "$TEMP_TARGET" "$TARGET" || \
        ERROR_EXIT "Failed to install $IMAGE_NAME in $KERNEL_OUT"
    LOG_INFO "Downloaded latest $IMAGE_NAME from Astro kernel repo"
}

DOWNLOAD_KERNEL_IMAGE "boot.img"
DOWNLOAD_KERNEL_IMAGE "dtbo.img"

unset KERNEL_REPO
unset KERNEL_OUT

LOG_END "Astro kernel download patch applied successfully"
