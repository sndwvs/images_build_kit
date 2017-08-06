
FIRMWARE="firmware-overlay"

SERIAL_CONSOLE_SPEED=115200

IMAGE_OFFSET=2048

case "$KERNEL_SOURCE" in
    next)
            URL_LINUX_SOURCE="http://mirror.yandex.ru/pub/linux/kernel/v4.x"
            LINUX_SOURCE="linux-$(wget --no-check-certificate -qO- https://www.kernel.org/finger_banner | grep 'The latest stable' | awk '{print $NF}' | head -n1)"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac

URL_SUNXI_TOOLS="https://github.com/linux-sunxi"
SUNXI_TOOLS="sunxi-tools"
SUNXI_TOOLS_BRANCH="" #"v1.2"

BOOT_LOADER_BIN="u-boot-sunxi-with-spl.bin"



write_uboot()
{
    message "" "write" "$BOOT_LOADER"
    # clear u-boot
    dd if=/dev/zero of=$1 bs=1k count=1023 seek=1 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    dd if="$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" of=$1 bs=1024 seek=8 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}
