
INITRD_MODULES="ext4:btrfs:xfs"

BOOT_LOADER_TOOLS_SOURCE="https://github.com/hardkernel/u-boot.git"
BOOT_LOADER_TOOLS_DIR="u-boot-tools-amlogic"
BOOT_LOADER_TOOLS_BRANCH="odroidg12-v2015.01::"

BOOT_FIP_SOURCE="https://github.com/radxa/amlogic-boot-fip.git"
BOOT_FIP_DIR="u-boot-amlogic-fip"
BOOT_FIP_BRANCH="master::"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyAML0

IMAGE_OFFSET=8192

BOOT_LOADER_BIN="u-boot.bin"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/hardkernel/linux.git"
            KERNEL_BRANCH="odroidg12-4.9.y::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




create_uboot()
{
    if [[ -f $CWD/blobs/amlogic/boot/$BOARD_NAME/u-boot-${KERNEL_SOURCE}.bin ]]; then
        install -Dm644 $CWD/blobs/amlogic/boot/$BOARD_NAME/u-boot-${KERNEL_SOURCE}.bin $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        return 0
    fi

    pushd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    install -Dm644 $BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN of=$1 conv=fsync bs=512 seek=1 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: $BOOT_LOADER_BIN"
    fi
}



