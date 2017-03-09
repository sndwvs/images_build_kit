
FIRMWARE="firmware-overlay"

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
