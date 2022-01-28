
INITRD_MODULES="ext4:btrfs:xfs"

BOOT_LOADER_TOOLS_SOURCE="https://github.com/hardkernel/u-boot.git"
BOOT_LOADER_TOOLS_DIR="u-boot-tools-amlogic"
BOOT_LOADER_TOOLS_BRANCH="odroidg12-v2015.01::"

BOOT_FIP_SOURCE="https://github.com/LibreELEC/amlogic-boot-fip.git"
BOOT_FIP_DIR="u-boot-amlogic-fip"
BOOT_FIP_BRANCH="master::"

BOOT_PACKER_LOADER_SOURCE="https://github.com/angerman/meson64-tools.git"
BOOT_PACKER_LOADER_DIR="u-boot-amlogic-packer"
BOOT_PACKER_LOADER_BRANCH="master::"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyAML0

IMAGE_OFFSET=8192

BOOT_LOADER_BRANCH="master:tag:v2022.01"
BOOT_LOADER_BIN="u-boot.bin"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/unifreq/linux-5.10.y.git"
            KERNEL_BRANCH="main::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




# additional function of preparing the bootloader for family g12a or g12b: S922X, S905X3, S905Y2
uboot_g12_processing()
{
    local g12="$1"
    local FIP_DIR="$SOURCE/$BOOT_FIP_DIR/${BOARD_NAME/_/-}"

    [[ ${BOARD_NAME} == x96_max_plus ]] && ( ln -sf $SOURCE/$BOOT_FIP_DIR/sei610 $FIP_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    message "" "start" "uboot_${g12}_processing: ${BOARD_NAME}"

    install -Dm644 $SOURCE/$BOOT_LOADER_DIR/$BOOT_LOADER_BIN $FIP_DIR/bl33.bin >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # simulate blx_fix.sh
    $SOURCE/$BOOT_PACKER_LOADER_DIR/pkg $FIP_DIR/bl30.bin \
                                        $FIP_DIR/bl301.bin \
                                        --output $FIP_DIR/bl30_new.bin \
                                        --type bl30 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    $SOURCE/$BOOT_PACKER_LOADER_DIR/pkg $FIP_DIR/bl2.bin \
                                        $FIP_DIR/acs.bin \
                                        --output $FIP_DIR/bl2_new.bin \
                                        --type bl2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    $SOURCE/$BOOT_PACKER_LOADER_DIR/bl30sig \
                            --input $FIP_DIR/bl30_new.bin \
                            --output $FIP_DIR/bl30_new.bin.g12.enc \
                            --level v3 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    $SOURCE/$BOOT_PACKER_LOADER_DIR/bl3sig \
                            --input $FIP_DIR/bl30_new.bin.g12.enc \
                            --output $FIP_DIR/bl30_new.bin.enc \
                            --level v3 \
                            --type bl30 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    $SOURCE/$BOOT_PACKER_LOADER_DIR/bl3sig \
                            --input $FIP_DIR/bl31.img \
                            --output $FIP_DIR/bl31.img.enc \
                            --level v3 \
                            --type bl31 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    $SOURCE/$BOOT_PACKER_LOADER_DIR/bl3sig \
                            --input $FIP_DIR/bl33.bin \
                            --compress lz4 \
                            --output $FIP_DIR/bl33.bin.enc \
                            --level v3 \
                            --type bl33 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    $SOURCE/$BOOT_PACKER_LOADER_DIR/bl2sig \
                            --input $FIP_DIR/bl2_new.bin \
                            --output $FIP_DIR/bl2.n.bin.sig >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [ -e $FIP_DIR/lpddr3_1d.fw ]; then
        $SOURCE/$BOOT_PACKER_LOADER_DIR/bootmk --output $FIP_DIR/u-boot.bin \
                        --bl2 $FIP_DIR/bl2.n.bin.sig \
                        --bl30 $FIP_DIR/bl30_new.bin.enc \
                        --bl31 $FIP_DIR/bl31.img.enc \
                        --bl33 $FIP_DIR/bl33.bin.enc \
                        --ddrfw1 $FIP_DIR/ddr4_1d.fw \
                        --ddrfw2 $FIP_DIR/ddr4_2d.fw \
                        --ddrfw3 $FIP_DIR/ddr3_1d.fw \
                        --ddrfw4 $FIP_DIR/piei.fw \
                        --ddrfw5 $FIP_DIR/lpddr4_1d.fw \
                        --ddrfw6 $FIP_DIR/lpddr4_2d.fw \
                        --ddrfw7 $FIP_DIR/diag_lpddr4.fw \
                        --ddrfw8 $FIP_DIR/aml_ddr.fw \
                        --ddrfw9 $FIP_DIR/lpddr3_1d.fw \
                        --level v3 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    else
        $SOURCE/$BOOT_PACKER_LOADER_DIR/bootmk --output $FIP_DIR/u-boot.bin \
                        --bl2 $FIP_DIR/bl2.n.bin.sig \
                        --bl30 $FIP_DIR/bl30_new.bin.enc \
                        --bl31 $FIP_DIR/bl31.img.enc \
                        --bl33 $FIP_DIR/bl33.bin.enc \
                        --ddrfw1 $FIP_DIR/ddr4_1d.fw \
                        --ddrfw2 $FIP_DIR/ddr4_2d.fw \
                        --ddrfw3 $FIP_DIR/ddr3_1d.fw \
                        --ddrfw4 $FIP_DIR/piei.fw \
                        --ddrfw5 $FIP_DIR/lpddr4_1d.fw \
                        --ddrfw6 $FIP_DIR/lpddr4_2d.fw \
                        --ddrfw7 $FIP_DIR/diag_lpddr4.fw \
                        --ddrfw8 $FIP_DIR/aml_ddr.fw \
                        --level v3 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


create_uboot()
{
#    if [[ -f $CWD/blobs/amlogic/boot/$BOARD_NAME/u-boot-${KERNEL_SOURCE}.bin ]]; then
#        install -Dm644 $CWD/blobs/amlogic/boot/$BOARD_NAME/u-boot-${KERNEL_SOURCE}.bin $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#        return 0
#    fi

    install -Dm644 $SOURCE/$BOOT_FIP_DIR/${BOARD_NAME/_/-}/$BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN of=$1 conv=fsync bs=512 seek=1 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: $BOOT_LOADER_BIN"
    fi
}



