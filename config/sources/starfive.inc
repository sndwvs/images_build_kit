
INITRD_MODULES="tun:btrfs:xfs"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=2048


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/starfive-tech/linux"
            KERNEL_BRANCH="visionfive::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
    next)
            LINUX_SOURCE="https://github.com/starfive-tech/linux"
            KERNEL_BRANCH="visionfive::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




create_uboot()
{
    pushd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    # clear u-boot
    dd if=/dev/zero of=$1 bs=1k count=1023 seek=1 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    message "" "write" "$BOOT_LOADER_DIR"
}




