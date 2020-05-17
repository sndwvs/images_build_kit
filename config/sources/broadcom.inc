
INITRD_MODULES="ext4:btrfs:xfs"

FIRMWARE="firmware"

SERIAL_CONSOLE_SPEED=115200
SERIAL_CONSOLE=ttyAMA0

BOOT_LOADER_BIN="u-boot.bin"


case $KERNEL_SOURCE in
    legacy)
            LINUX_SOURCE="https://github.com/raspberrypi/linux.git"
            KERNEL_BRANCH="rpi-4.19.y::"
            KERNEL_DIR="linux-$SOCFAMILY-$KERNEL_SOURCE"
    ;;
    next)
            LINUX_SOURCE="https://github.com/raspberrypi/linux.git"
            KERNEL_BRANCH="rpi-5.6.y::"
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

    cat <<EOF >"$SOURCE/$IMAGE/boot/config.txt"
# See /boot/overlays/README for all available options

gpu_mem=64
#initramfs initramfs-linux.img followkernel
kernel=$BOOT_LOADER_BIN
arm_64bit=1
enable_gic=1
disable_overscan=1

#enable sound
dtparam=audio=on
hdmi_drive=2

#enable vc4
dtoverlay=vc4-fkms-v3d
max_framebuffers=2
EOF

    echo "root=/dev/mmcblk0p2 rw rootwait console=ttyAMA0,115200 console=tty1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 kgdboc=ttyAMA0,115200 elevator=noop snd-bcm2835.enable_compat_alsa=0" \
    > "$SOURCE/$IMAGE/boot/cmdline.txt"

    if [[ -f $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN ]]; then
        install -Dm644 $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/$BOOT_LOADER_BIN $SOURCE/$IMAGE/boot/$BOOT_LOADER_BIN >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        message "" "write" "bootloader: $BOOT_LOADER_BIN"
    fi
}

