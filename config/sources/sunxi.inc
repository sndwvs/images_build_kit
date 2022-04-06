
INITRD_MODULES="tun:btrfs:xfs"

ATF_BRANCH="master:tag:v2.6"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=2048

ROOT_DISK="mmcblk0p1"

BOOT_LOADER_BRANCH="master:tag:v2021.10"
BOOT_LOADER_BIN="u-boot-sunxi-with-spl.bin"

if [[ ${SOCFAMILY} == sun7i ]]; then
    OVERLAY_PREFIX="${SOCFAMILY}-a20"
elif [[ ${SOCFAMILY} == sun8i ]]; then
    OVERLAY_PREFIX="${SOCFAMILY}-h3"
elif [[ ${SOCFAMILY%w*}-a64 == sun50iw1 ]]; then
    OVERLAY_PREFIX="${SOCFAMILY%w*}-a64"
fi


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/megous/linux"
            KERNEL_BRANCH="orange-pi-5.4::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
    next)
            LINUX_SOURCE="https://github.com/megous/linux"
            KERNEL_BRANCH="orange-pi-5.17::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




create_uboot()
{
    pushd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    if [[ $SOCFAMILY == sun?i ]]; then
        install -Dm644 $BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    else
        install -Dm644 spl/sunxi-spl.bin $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/sunxi-spl.bin >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 u-boot*.itb $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/u-boot.itb >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    message "" "write" "$BOOT_LOADER_DIR"
    # clear u-boot
    dd if=/dev/zero of=$1 bs=1k count=1023 seek=1 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    if [[ $SOCFAMILY == sun?i ]]; then
        dd if="$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN" of=$1 bs=1024 seek=8 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    else
        dd if="$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/sunxi-spl.bin" of=$1 bs=8k seek=1 conv=fsync >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        dd if="$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/u-boot.itb" of=$1 bs=8k seek=5 conv=fsync >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}



