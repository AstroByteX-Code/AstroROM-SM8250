#https://github.com/pascua28/MintOS/commit/42c2a5aad62e5e9bcba3cdcfad7c38cb6e92a3c8

LOG_BEGIN "Adding FBE v2 support"

while IFS= read -r -d '' FSTAB; do
    LOG_INFO "Patching $(basename "$FSTAB")"

    # Only replace userdata mount line if present
    sed -i '\|/dev/block/bootdevice/by-name/userdata|c\
/dev/block/bootdevice/by-name/userdata                 /data                  f2fs    noatime,nosuid,nodev,discard,usrquota,grpquota,fsync_mode=nobarrier,reserve_root=32768,resgid=5678,inlinecrypt    latemount,wait,check,fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized,keydirectory=/metadata/vold/metadata_encryption,sysfs_path=/sys/devices/platform/soc/1d84000.ufshc,quota,reservedsize=128M,checkpoint=fs' \
        "$FSTAB"

done < <(
    find "$WORKSPACE/vendor/etc" \
        -type f \
        -name "fstab*" \
        -print0
)

LOG_END "FBE v2 support applied successfully"

