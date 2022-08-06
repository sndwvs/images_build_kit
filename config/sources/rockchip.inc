
INITRD_MODULES="tun:btrfs:xfs"

ATF_BRANCH="master:tag:v2.7"

RKBIN_SOURCE="https://github.com/rockchip-linux/rkbin.git"
RKBIN_DIR="rkbin"
RKBIN_BRANCH="master::"

BOOT_LOADER_TOOLS_SOURCE="https://github.com/rockchip-linux/u-boot.git"
#BOOT_LOADER_TOOLS_SOURCE="https://github.com/Caesar-github/u-boot.git"
BOOT_LOADER_TOOLS_DIR="u-boot-tools-rockchip"
BOOT_LOADER_TOOLS_BRANCH="next-dev::"

BOOT_LOADER_BRANCH="master:tag:v2022.07"
BOOT_LOADER_BIN="idbloader.img"


# BOOT_LOADER_BUILD_TYPE - determines which tpl (ddrblob), spl (miniloader) and ATF combination to use
#
# Different types of bootloader creation:
# 1: DDR initialization (proprietary rockchip ddrblob or u-boot TPL)
# 2: Initial system and clock initialization (proprietary rockchip miniloader or u-boot SPL)
# 3: Arm Trusted Firmware (proprietary rockchip or mainline opensource)
# 4: u-boot proper is always the mainline one
#
# Available options for BOOT_LOADER_BUILD_TYPE are:
# 1: blobs: proprietary rockchip ddrbin, miniloader and ATF
# 2: spl-blob: proprietary rockchip ddrblob and ATF, but uses mainline u-boot SPL in place of rockchip miniloader
# 3: tpl-spl-blob: uses mainline u-boot TPL and SPL with proprietary rockchip ATF blob
# 4: tpl-blob-atf-mainline: proprietary rockchip ddrblob + mainline u-boot SPL + mainline ATF
# 5: free-blobs: mainline u-boot TPL + mainline u-boot SPL + mainline ATF

BOOT_LOADER_BUILD_TYPE="free-blobs"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=32768

OVERLAY_PREFIX="rockchip"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/rockchip-linux/kernel"
            KERNEL_BRANCH="develop-4.4::"
#            KERNEL_BRANCH="release-4.4:commit:763b2b0fabd8e52c38aa43b5eca9752073bd0993"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
#    next)
#            KERNEL_BRANCH="linux-5.10.y::"
#    ;;
esac



create_uboot()
{
    pushd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # u-boot
    #
    # Total hours wasted before finding that the new "load address" parameter is not optional: 3
    # https://github.com/rockchip-linux/build/commit/fff8f5a2d91fd11f8c4f6d605cac704d28baab4d
    #
    LOAD_ADDRESS="0x200000"
    [[ $SOCFAMILY == rk3308 ]] && LOAD_ADDRESS="0x600000"

    if [[ $SOCFAMILY == rk32* ]]; then
        # U-Boot SPL, with SPL_BACK_TO_BROM option enabled
#        tools/mkimage -n $SOCFAMILY -T rksd -d spl/u-boot-spl-dtb.bin $BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#        cat u-boot-dtb.bin >> $BOOT_LOADER_BIN || exit 1
        install -Dm644 $BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 u-boot-dtb.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/uboot.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi


    if [[ $BOOT_LOADER_BUILD_TYPE == "free-blobs" || $BOOT_LOADER_BUILD_TYPE == "tpl-spl-blob" ]]; then

        tools/mkimage -n $SOCFAMILY -T rksd -d tpl/u-boot-tpl.bin:spl/u-boot-spl.bin $BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 u-boot.itb $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/u-boot.itb >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    elif [[ $BOOT_LOADER_BUILD_TYPE == "spl-blob" || $BOOT_LOADER_BUILD_TYPE == "tpl-blob-atf-mainline" ]]; then

        tools/mkimage -n $SOCFAMILY -T rksd -d $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$DDR_BLOB:spl/u-boot-spl.bin $BOOT_LOADER_BIN \
        >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 u-boot.itb $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/u-boot.itb >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    elif [[ $BOOT_LOADER_BUILD_TYPE == "blobs" ]]; then

        tools/mkimage -n $SOCFAMILY -T rksd -d $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$DDR_BLOB $BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        cat $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$MINI_LOADER_BLOB >> $BOOT_LOADER_BIN || exit 1
        $SOURCE/$BOOT_LOADER_TOOLS_DIR/tools/loaderimage --pack --uboot u-boot-dtb.bin uboot.img $LOAD_ADDRESS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 uboot.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/uboot.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        $SOURCE/$BOOT_LOADER_TOOLS_DIR/tools/trust_merger $CWD/config/atf/$SOCFAMILY/trust.ini >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 trust.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    fi

    if [[ $BOOT_LOADER_SPI = yes ]] ; then

        tools/mkimage -n $SOCFAMILY -T rkspi -d tpl/u-boot-tpl.bin:spl/u-boot-spl.bin rkspi_tpl_spl.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        dd if=/dev/zero of=rkspi_loader.img count=8192 status=none >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        dd if=rkspi_tpl_spl.img of=rkspi_loader.img conv=notrunc status=none >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        dd if=u-boot.itb of=rkspi_loader.img seek=768 conv=notrunc status=none >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 rkspi_loader.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/rkspi_loader.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

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
        message "" "write" "bootloader: uboot.img"
    fi
    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img of=$1 seek=24576 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: trust.img"
    fi
}



