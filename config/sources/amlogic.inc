
INITRD_MODULES="ext4:btrfs:xfs"

BOOT_LOADER_TOOLS_SOURCE="https://github.com/hardkernel/u-boot.git"
BOOT_LOADER_TOOLS_DIR="u-boot-tools-amlogic"
BOOT_LOADER_TOOLS_BRANCH="odroidg12-v2015.01::"

FIRMWARE="firmware"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyAML0

IMAGE_OFFSET=2048

BOOT_LOADER_BIN="u-boot.bin"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/hardkernel/linux.git"
            KERNEL_BRANCH="odroidg12-4.9.y::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




create_uboot()
{
    if [[ -f $CWD/blobs/amlogic/boot/$BOARD_NAME/u-boot-${KERNEL_SOURCE}.bin ]]; then
        install -Dm644 $CWD/blobs/amlogic/boot/$BOARD_NAME/u-boot-${KERNEL_SOURCE}.bin $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        return 0
    fi

    pushd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    install -Dm644 $BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN ]]; then
        dd if=$BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN of=$1 conv=fsync bs=512 seek=1 status=noxfer >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: $BOOT_LOADER_BIN"
    fi
}

#create_img() {
#
#    if [[ $1 == xfce ]]; then
#        IMAGE="$ROOTFS_XFCE"
#    else
#        IMAGE="$ROOTFS"
#    fi
#
#    # +800M for create swap firstrun
#    ROOTFS_SIZE=$(rsync -an --stats $SOURCE/$IMAGE test | grep "Total file size" | sed 's/[^0-9]//g' | xargs -I{} expr {} / $((1024*1024)) + 1000)"M"
#
#    message "" "create" "image size $ROOTFS_SIZE"
#
#    dd if=/dev/zero of=$SOURCE/$IMAGE.img bs=1 count=0 seek=$ROOTFS_SIZE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#
#    LOOP=$(losetup -f)
#
#    losetup $LOOP $SOURCE/$IMAGE.img || exit 1
#
#    message "" "create" "partition"
#    echo -e "\no\nn\np\n1\n$IMAGE_OFFSET\n+100M\n\nt\nc\nn\np\n2\n\n\nw" | fdisk $LOOP >> $LOG 2>&1 || true
#
#    partprobe $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#
#    message "" "create" "filesystem"
#    mkfs.vfat ${LOOP}p1 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#    mkfs.ext4 -F -m 0 -L linuxroot ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#
#    message "" "tune" "filesystem"
#    tune2fs -o journal_data_writeback ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#    tune2fs -O ^has_journal ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#    e2fsck -yf ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#
#    message "" "create" "mount point and mount image"
#
#    mkdir -p $SOURCE/image
#    mount ${LOOP}p2 $SOURCE/image
#    mkdir -p $SOURCE/image/boot
#    mount ${LOOP}p1 $SOURCE/image/boot
#
#    write_uboot $LOOP
#
#    rsync -a "$SOURCE/$IMAGE/" "$SOURCE/image/"
#
#    umount $SOURCE/image/boot
#    umount $SOURCE/image
#
#    if [[ -d $SOURCE/image ]]; then
#        rm -rf $SOURCE/image
#    fi
#    losetup -d $LOOP
#
#    if [[ -f $SOURCE/$IMAGE.img ]]; then
#        mv $SOURCE/$IMAGE.img $BUILD/$OUTPUT/$IMAGES
#    fi
#
#    message "" "done" "image $IMAGE"
#}

