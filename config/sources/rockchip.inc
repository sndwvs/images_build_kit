
LINUX_UPGRADE_TOOL="Linux_Upgrade_Tool_v1.21"

URL_RK2918_TOOLS="https://github.com/dayongxie"
RK2918_TOOLS="rk2918_tools"

URL_RKBIN="https://github.com/rockchip-linux"
RKBIN="rkbin"

URL_TOOLS="https://github.com/neo-technologies"
MKBOOTIMG_TOOLS="rockchip-mkbootimg"
RKFLASH_TOOLS="rkflashtool"
#FIRMWARE="master.zip"
FIRMWARE="firmware-overlay"

SERIAL_CONSOLE_SPEED=115200

IMAGE_OFFSET=2048

case $KERNEL_SOURCE in
    legacy)
            URL_LINUX_SOURCE="https://github.com/rockchip-linux"
            LINUX_SOURCE="kernel"
            KERNEL_BRANCH="release-4.4"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
    next)
            URL_LINUX_SOURCE="https://github.com/rockchip-linux"
            LINUX_SOURCE="kernel"
            KERNEL_BRANCH="release-4.4"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac


BOOT_LOADER_BIN="u-boot-$SOCFAMILY-with-spl.bin"


create_uboot()
{
    # U-Boot SPL, with SPL_BACK_TO_BROM option enabled
    tools/mkimage -n $SOCFAMILY -T rksd -d spl/u-boot-spl-dtb.bin $BOOT_LOADER_BIN
    cat u-boot-dtb.bin >> $BOOT_LOADER_BIN
}


#write_uboot()
#{
    # clear u-boot
#    dd if=/dev/zero of=$1 bs=1k count=1023 seek=1 status=noxfer > /dev/null 2>&1
#    dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN of=$1 seek=64 status=noxfer > /dev/null 2>&1
#}
