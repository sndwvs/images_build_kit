
INITRD_MODULES="ext4:btrfs:xfs"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=2048

BOOT_LOADER_BIN="u-boot.bin"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/raspberrypi/linux.git"
            KERNEL_BRANCH="rpi-5.10.y::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
    next)
            LINUX_SOURCE="https://github.com/raspberrypi/linux.git"
            KERNEL_BRANCH="rpi-5.14.y::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
esac




create_uboot()
{
    pushd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    install -Dm644 $BOOT_LOADER_BIN $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


write_uboot()
{
    echo "root=/dev/mmcblk0p2 ro rootwait nofont console=tty1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 elevator=noop snd-bcm2835.enable_compat_alsa=0" \
    > "$SOURCE/$IMAGE/boot/cmdline.txt"

    install -m644 -D $CWD/blobs/broadcom/boot/* -t $SOURCE/$ROOTFS/boot

    # set name boot kernel
    sed -e "s:%BOOT_LOADER_BIN%:${BOOT_LOADER_BIN}:g" \
        -i "$SOURCE/$ROOTFS/boot/config.txt"

    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN ]]; then
        message "" "write" "bootloader: $BOOT_LOADER_BIN"
        install -Dm644 $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN $SOURCE/$IMAGE/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}

build_img() {
    local IMAGE="$1"

    [[ -z "$IMAGE" ]] && exit 1

    message "" "build" "image: $IMAGE"

    LOOP=$(losetup -f)

    losetup $LOOP $SOURCE/$IMAGE.img || exit 1

    message "" "create" "partition"
    echo -e "\no\nn\np\n1\n$IMAGE_OFFSET\n+256M\n\nt\nc\nn\np\n2\n\n\nw" | fdisk $LOOP >> $LOG 2>&1 || true

    partprobe $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "create" "filesystem"
    mkfs.vfat ${LOOP}p1 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    mkfs.ext4 -F -m 0 -L linuxroot ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "tune" "filesystem"
    tune2fs -o journal_data_writeback ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    tune2fs -O ^has_journal ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    e2fsck -yf ${LOOP}p2 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "create" "mount point and mount image"

    mkdir -p $SOURCE/image
    mount ${LOOP}p2 $SOURCE/image
    mkdir -p $SOURCE/image/boot
    mount ${LOOP}p1 $SOURCE/image/boot

    write_uboot $LOOP

    rsync -a "$SOURCE/$IMAGE/" "$SOURCE/image/"

    umount $SOURCE/image/boot
    umount $SOURCE/image

    if [[ -d $SOURCE/image ]]; then
        rm -rf $SOURCE/image
    fi
    losetup -d $LOOP

    if [[ -f $SOURCE/$IMAGE.img ]]; then
        mv $SOURCE/$IMAGE.img $BUILD/$OUTPUT/$IMAGES
    fi

    message "" "done" "build image"
}

