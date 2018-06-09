
LINUX_UPGRADE_TOOL="Linux_Upgrade_Tool_v1.21"

URL_RK2918_TOOLS="https://github.com/dayongxie"
RK2918_TOOLS="rk2918_tools"

URL_RKBIN="https://github.com/rockchip-linux"
RKBIN="rkbin"
RKBIN_BRANCH=""

URL_TOOLS="https://github.com/neo-technologies"
MKBOOTIMG_TOOLS="rockchip-mkbootimg"
RKFLASH_TOOLS="rkflashtool"
FIRMWARE="firmware-overlay"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=32768

#BOOT_LOADER_BIN="idbloader.img:idbloader_mmc.img:uboot.img:trust.img"
BOOT_LOADER_BIN="idbloader.img"


URL_ATF="https://github.com/ARM-software"
ATF_SOURCE="arm-trusted-firmware"
ATF_BRANCH=${ATF_BRANCH:-master}


case $KERNEL_SOURCE in
    legacy)
            URL_LINUX_SOURCE="https://github.com/rockchip-linux"
            LINUX_SOURCE="kernel"
            KERNEL_BRANCH="release-4.4"
#            KERNEL_COMMIT="763b2b0fabd8e52c38aa43b5eca9752073bd0993"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




create_uboot()
{
    pushd $CWD/$BUILD/$SOURCE/$BOOT_LOADER >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk32* ]]; then
        # U-Boot SPL, with SPL_BACK_TO_BROM option enabled
        tools/mkimage -n $SOCFAMILY -T rksd -d spl/u-boot-spl-dtb.bin $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#        tools/mkimage -n $SOCFAMILY -T rksd -d $CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        cat u-boot-dtb.bin >> $BOOT_LOADER_BIN || exit 1
    fi

    if [[ $SOCFAMILY == rk33* ]]; then
        # The ddr binary files for ARM64 platforms from Rockchip, likes RK3399 and RK3328 should not skip first 4 bytes.
        # U-Boot SPL, with SPL_BACK_TO_BROM option disabled SD
        tools/mkimage -n $SOCFAMILY -T rksd -d $CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        cat $CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$MINI_LOADER >> $BOOT_LOADER_BIN || exit 1

        # u-boot
        #
        # Total hours wasted before finding that the new "load address" parameter is not optional: 3
        # https://github.com/rockchip-linux/build/commit/fff8f5a2d91fd11f8c4f6d605cac704d28baab4d
        #
        $CWD/$BUILD/$SOURCE/$RKBIN/tools/loaderimage --pack --uboot u-boot-dtb.bin uboot.img 0x200000 >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    popd >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    # clear u-boot
#    dd if=/dev/zero of=$1 bs=1k count=1023 seek=1 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN of=$1 seek=64 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    if [[ $SOCFAMILY == rk33* ]]; then
        dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER/uboot.img of=$1 seek=16384 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        dd if=$CWD/$BUILD/$SOURCE/$ATF_SOURCE/trust.img of=$1 seek=24576 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    message "" "write" "$BOOT_LOADER"
}
