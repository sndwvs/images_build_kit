
FIRMWARE="firmware"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=2048

ROOT_DISK="mmcblk0p1"

URL_SUNXI_TOOLS="https://github.com/linux-sunxi"
SUNXI_TOOLS="sunxi-tools"
SUNXI_TOOLS_BRANCH="" #"v1.2"

#BOOT_LOADER_BRANCH="master:tag:v2018.05"
BOOT_LOADER_BIN="u-boot-sunxi-with-spl.bin"


case $KERNEL_SOURCE in
    next)
            LINUX_SOURCE="https://github.com/megous/linux"
            KERNEL_BRANCH="orange-pi-4.19::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




write_uboot()
{
    message "" "write" "$BOOT_LOADER_DIR"
    # clear u-boot
    dd if=/dev/zero of=$1 bs=1k count=1023 seek=1 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    dd if="$SOURCE/$BOOT_LOADER_DIR/$BOOT_LOADER_BIN" of=$1 bs=1024 seek=8 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}
