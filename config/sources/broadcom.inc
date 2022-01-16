
INITRD_MODULES="ext4:btrfs:xfs"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyS0

IMAGE_OFFSET=2048

BOOT_LOADER_FIRMWARE_SOURCE=" https://github.com/raspberrypi/firmware.git"
BOOT_LOADER_FIRMWARE_DIR="boot-loader-firmware-broadcom"
BOOT_LOADER_FIRMWARE_BRANCH="next::"

BOOT_LOADER_BIN="u-boot.bin"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/raspberrypi/linux.git"
            KERNEL_BRANCH="rpi-5.10.y::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
    next)
            LINUX_SOURCE="https://github.com/raspberrypi/linux.git"
            KERNEL_BRANCH="rpi-5.16.y::"
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
cat <<EOF>$SOURCE/$IMAGE/boot/config.txt
# See /boot/overlays/README for all available options

# Our kernels are located on a Linux partition. Chainload U-Boot to load them.
kernel=${BOOT_LOADER_BIN}
#kernel=Image

# Use 32 MB for GPU for all RPis (Min 16 - Max 192 MB)
# We don't need that much memory reserved for it, because we drive most hardware
# from Linux, not the VPU OS
gpu_mem=32

arm_64bit=1

# Turbo mode: 0 = enable dynamic freq/voltage - 1 = always max
force_turbo=0
# Start in turbo mode for 30 seconds or until cpufreq sets a frequency
initial_turbo=30

# DO NOT overvoltage manually to not void warranty!
over_voltage=0

# Fix mini UART input frequency, and setup/enable up the UART.
enable_uart=1

# Disable warning overlays as they don't work well together with linux's graphical output
avoid_warnings=1

# This overlay fixes divergences between the RPi device tree and what
# upstream provides
dtoverlay=upstream

# overscan is only needed on old TV sets and if analog gear is in the chain (e.g. DPI)
disable_overscan=1

[pi3]
# These are not applied automatically? Needed to use respective upstream drivers.
dtoverlay=vc4-kms-v3d,cma-default
dtoverlay=dwc2

[pi4]
dtoverlay=vc4-fkms-v3d
#dtoverlay=vc4-kms-v3d

[all]
dtparam=i2c_arm=on
dtparam=spi=on
dtparam=audio=on
EOF

    echo "root=/dev/mmcblk0p2 ro rootwait nofont console=tty1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 elevator=noop snd-bcm2835.enable_compat_alsa=0" \
    > "$SOURCE/$IMAGE/boot/cmdline.txt"

    cp -v $SOURCE/$BOOT_LOADER_FIRMWARE_DIR/boot/{*.dat,*.bin,*.elf} $SOURCE/$IMAGE/boot >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

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

