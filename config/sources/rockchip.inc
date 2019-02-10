
URL_RKBIN="https://github.com/rockchip-linux"
RKBIN="rkbin"
RKBIN_BRANCH="${RKBIN_BRANCH:-29mirror}"

FIRMWARE="firmware"

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
            LINUX_SOURCE="https://github.com/rockchip-linux/kernel"
            KERNEL_BRANCH="release-4.4::"
#            KERNEL_BRANCH="release-4.4:commit:763b2b0fabd8e52c38aa43b5eca9752073bd0993"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




create_uboot()
{
    pushd $CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk32* ]]; then
        # U-Boot SPL, with SPL_BACK_TO_BROM option enabled
        tools/mkimage -n $SOCFAMILY -T rksd -d spl/u-boot-spl-dtb.bin $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#        tools/mkimage -n $SOCFAMILY -T rksd -d $CWD/$BUILD/$SOURCE/$RKBIN/bin/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        cat u-boot-dtb.bin >> $BOOT_LOADER_BIN || exit 1
    fi

    if [[ $SOCFAMILY == rk33* ]]; then
        if [[ $BOARD_NAME == rockpro64 ]] || [[ $BOARD_NAME == rock_pi_4 ]]; then
            tools/mkimage -n $SOCFAMILY -T rksd -d $CWD/$BUILD/$SOURCE/$RKBIN/bin/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN rksd_loader.img
            cat spl/u-boot-spl.bin >> rksd_loader.img
            dd if=u-boot.itb of=rksd_loader.img seek=448 conv=notrunc
            tools/mkimage -n $SOCFAMILY -T rksd -d $CWD/$BUILD/$SOURCE/$RKBIN/bin/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN rkspi_loader.img
            cat spl/u-boot-spl.bin >> rkspi_loader.img
            for i in `seq 1 128`; do dd count=4 status=none; dd if=/dev/zero count=4 status=none; done < rkspi_loader.img > rkspi_loader.tmp
            mv rkspi_loader.tmp rkspi_loader.img
            dd if=u-boot.itb of=rkspi_loader.img seek=1024 conv=notrunc
        else
            # The ddr binary files for ARM64 platforms from Rockchip, likes RK3399 and RK3328 should not skip first 4 bytes.
            # U-Boot SPL, with SPL_BACK_TO_BROM option disabled SD
            tools/mkimage -n $SOCFAMILY -T rksd -d $CWD/$BUILD/$SOURCE/$RKBIN/bin/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

            cat $CWD/$BUILD/$SOURCE/$RKBIN/bin/${SOCFAMILY:0:4}/$MINI_LOADER >> $BOOT_LOADER_BIN || exit 1

            if [[ $NATIVE_ARCH != true ]]; then
                # u-boot
                #
                # Total hours wasted before finding that the new "load address" parameter is not optional: 3
                # https://github.com/rockchip-linux/build/commit/fff8f5a2d91fd11f8c4f6d605cac704d28baab4d
                #
                $CWD/$BUILD/$SOURCE/$RKBIN/tools/loaderimage --pack --uboot u-boot-dtb.bin uboot.img 0x200000 >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
        fi
    fi
    popd >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    # clear u-boot
#    dd if=/dev/zero of=$1 bs=1k count=$((${IMAGE_OFFSET}-1)) seek=1 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $BOARD_NAME == rockpro64 ]] || [[ $BOARD_NAME == rock_pi_4 ]]; then
#        dd if=$CWD/blobs/$BOARD_NAME/u-boot/rksd_loader.img of=$1 seek=64 conv=notrunc status=none >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR/rksd_loader.img of=$1 seek=64 conv=notrunc status=none >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    else
        dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR/$BOOT_LOADER_BIN of=$1 seek=64 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        if [[ $SOCFAMILY == rk33* ]]; then
            dd if=$CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR/uboot.img of=$1 seek=16384 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            dd if=$CWD/$BUILD/$SOURCE/$ATF_SOURCE/trust.img of=$1 seek=24576 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi
    message "" "write" "$BOOT_LOADER_DIR"
}

fix_native_arch()
{
    cp -f $CWD/blobs/$BOARD_NAME/u-boot/uboot.img $CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    cp -f $CWD/blobs/$BOARD_NAME/atf/trust.img $CWD/$BUILD/$SOURCE/$ATF_SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}
