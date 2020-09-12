
INITRD_MODULES="tun:btrfs:xfs"

ATF_BRANCH="master:tag:v2.3"

RKBIN_SOURCE="https://github.com/rockchip-linux/rkbin.git"
#RKBIN_SOURCE="https://github.com/Caesar-github/rkbin.git"
RKBIN_DIR="rkbin"
RKBIN_BRANCH="master::"

BOOT_LOADER_TOOLS_SOURCE="https://github.com/rockchip-linux/u-boot.git"
BOOT_LOADER_TOOLS_DIR="u-boot-tools-rockchip"
BOOT_LOADER_TOOLS_BRANCH="next-dev::"

FIRMWARE="firmware"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=32768

#BOOT_LOADER_BIN="idbloader.img:idbloader_mmc.img:uboot.img:trust.img"
BOOT_LOADER_BIN="idbloader.img"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/rockchip-linux/kernel"
            KERNEL_BRANCH="develop-4.4::"
#            KERNEL_BRANCH="release-4.4:commit:763b2b0fabd8e52c38aa43b5eca9752073bd0993"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
#    next)
#            KERNEL_BRANCH="linux-5.8.y::"
#    ;;
esac




create_uboot()
{
    pushd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk32* ]]; then
        # U-Boot SPL, with SPL_BACK_TO_BROM option enabled
#        tools/mkimage -n $SOCFAMILY -T rksd -d spl/u-boot-spl-dtb.bin $BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#        cat u-boot-dtb.bin >> $BOOT_LOADER_BIN || exit 1
        install -Dm644 $BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 u-boot-dtb.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/uboot.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == rk33* ]]; then
#        if [[ $BOARD_NAME == rockpro64 || $BOARD_NAME == rock_pi_4 ]]; then
#            tools/mkimage -n $SOCFAMILY -T rksd -d $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#            cat spl/u-boot-spl.bin >> rksd_loader.img || exit 1
#            dd if=u-boot.itb of=rksd_loader.img seek=448 conv=notrunc >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#            tools/mkimage -n $SOCFAMILY -T rksd -d $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$DDR rkspi_loader.img
#            cat spl/u-boot-spl.bin >> rkspi_loader.img
#            for i in `seq 1 128`; do dd count=4 status=none; dd if=/dev/zero count=4 status=none; done < rkspi_loader.img > rkspi_loader.tmp
#            mv rkspi_loader.tmp rkspi_loader.img
#            dd if=u-boot.itb of=rkspi_loader.img seek=1024 conv=notrunc
        if [[ $BOARD_NAME == rockpro64 || $BOARD_NAME == rock_pi_4[abc] || $BOARD_NAME == pinebook_pro || $BOARD_NAME == rock64 || $BOARD_NAME == firefly_rk3399 || $BOARD_NAME == rock_pi_e ]]; then
            tools/mkimage -n $SOCFAMILY -T rksd -d tpl/u-boot-tpl.bin $BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            cat spl/u-boot-spl.bin >> $BOOT_LOADER_BIN || exit 1
            install -Dm644 u-boot.itb $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/u-boot.itb >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

            # remove ATF because it is included in u-boot.itb
            [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img ]] && rm $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

            tools/mkimage -n $SOCFAMILY -T rkspi -d tpl/u-boot-tpl.bin:spl/u-boot-spl.bin rkspi_tpl_spl.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            dd if=/dev/zero of=rkspi_loader.img count=8192 status=none >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            dd if=rkspi_tpl_spl.img of=rkspi_loader.img conv=notrunc status=none >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            dd if=u-boot.itb of=rkspi_loader.img seek=768 conv=notrunc status=none >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            install -Dm644 rkspi_loader.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/rkspi_loader.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            # The ddr binary files for ARM64 platforms from Rockchip, likes RK3399 and RK3328 should not skip first 4 bytes.
            # U-Boot SPL, with SPL_BACK_TO_BROM option disabled SD
            tools/mkimage -n $SOCFAMILY -T rksd -d $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$DDR $BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            cat $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$MINI_LOADER >> $BOOT_LOADER_BIN || exit 1

            # u-boot
            #
            # Total hours wasted before finding that the new "load address" parameter is not optional: 3
            # https://github.com/rockchip-linux/build/commit/fff8f5a2d91fd11f8c4f6d605cac704d28baab4d
            #
            LOAD_ADDRESS="0x200000"
            [[ $SOCFAMILY == rk3308 ]] && LOAD_ADDRESS="0x600000"
            $SOURCE/$BOOT_LOADER_TOOLS_DIR/tools/loaderimage --pack --uboot u-boot-dtb.bin uboot.img $LOAD_ADDRESS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            install -Dm644 uboot.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/uboot.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi
    install -Dm644 $BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    # clear u-boot
#    dd if=/dev/zero of=$1 bs=1k count=$((${IMAGE_OFFSET}-1)) seek=1 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN of=$1 seek=64 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: $BOOT_LOADER_BIN"
    fi
    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/u-boot.itb ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/u-boot.itb of=$1 seek=16384 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: u-boot-itb"
    fi
    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/uboot.img ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/uboot.img of=$1 seek=16384 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: uboot-img"
    fi
    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img of=$1 seek=24576 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: trust.img"
    fi
}

