
LINUX_UPGRADE_TOOL="Linux_Upgrade_Tool_v1.21"

URL_RK2918_TOOLS="https://github.com/dayongxie"
RK2918_TOOLS="rk2918_tools"

URL_RKBIN="https://github.com/rockchip-linux"
RKBIN="rkbin"
RKBIN_BRANCH="bdf68e257ca5aecbfac1bee4a55c64c97a3022f9"

URL_TOOLS="https://github.com/neo-technologies"
MKBOOTIMG_TOOLS="rockchip-mkbootimg"
RKFLASH_TOOLS="rkflashtool"
FIRMWARE="firmware-overlay"

SERIAL_CONSOLE_SPEED=115200

IMAGE_OFFSET=32768

#BOOT_LOADER_BIN="idbloader.img:idbloader_mmc.img:uboot.img:trust.img"
BOOT_LOADER_BIN="idbloader.img"




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




create_uboot()
{
    pushd $CWD/$BUILD/$SOURCE/$BOOT_LOADER >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk32* ]]; then
        # U-Boot SPL, with SPL_BACK_TO_BROM option enabled
        tools/mkimage -n $SOCFAMILY -T rksd -d spl/u-boot-spl-dtb.bin $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        cat u-boot-dtb.bin >> $BOOT_LOADER_BIN || exit 1
    fi

    if [[ $SOCFAMILY == rk33* ]]; then
        if [[ $1 == mmc ]];then
            tools/mkimage -n $SOCFAMILY -T rksd -d $CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            # U-Boot SPL, with SPL_BACK_TO_BROM option disabled SD
            dd if=$CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$DDR of=ddr.bin bs=4 skip=1 >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            tools/mkimage -n $SOCFAMILY -T rksd -d ddr.bin $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            rm ddr.bin || exit 1
        fi

        cat $CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$MINI_LOADER >> $BOOT_LOADER_BIN || exit 1
        $CWD/$BUILD/$SOURCE/$RKBIN/tools/loaderimage --pack --uboot u-boot.bin uboot.img >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    popd >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    message "" "write" "$BOOT_LOADER"
    # clear u-boot
#    dd if=/dev/zero of=$1 bs=1k count=1023 seek=1 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER/idbloader.img of=$1 seek=64 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER/uboot.img of=$1 seek=16384 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    [[ $SOCFAMILY == rk33* ]] && ( dd if=$CWD/$BUILD/$SOURCE/$RKBIN/img/$SOCFAMILY/trust.img of=$1 seek=24576 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
}
