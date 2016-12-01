#!/bin/sh

if [ "$EUID" -ne 0 ];then
    echo "Please run as root"
    exit 0
fi

DEVICE=$(lsusb -d 2207:320a)
DISK=$(dmesg | sed -n '/UMS/{n;p;}' | head -n1 | grep -oP '\[([a-z]*)\]' | sed "s/\W//g")

case "$1" in
    -b )
    shift
    BOOT="true"
    ;;
    -r )
    shift
    XFCE="false"
    ;;
    --xfce )
    shift
    XFCE="true"
    ;;
    *)
    echo -e "Options:"
    echo -e "\t-b"
    echo -e "\t\tflash boot loader"

    echo -e "\t-r"
    echo -e "\t\tflash mini rootfs image without xfce"

    echo -e "\t--xfce"
    echo -e "\t\tflash image with xfce\n"
    exit 0
    ;;
esac

# unpack tools
if [ -f $TOOLS-$(uname -m).tar.xz ];then
    echo "------ unpack $TOOLS"
    tar xf $TOOLS-$(uname -m).tar.xz || exit 1
fi

# unpack boot loader
if [ -f boot.tar.xz ];then
    echo "------ unpack boot loader"
    tar xf boot.tar.xz || exit 1
fi

# flash boot loader
if [[ "$BOOT" = "true" && ! -z $DEVICE ]]; then
    echo "------ flash boot loader"
    $TOOLS/upgrade_tool db     boot/rk3288_boot.bin || exit 1
    $TOOLS/upgrade_tool wl 64  boot/u-boot-dtb.bin || exit 1
    $TOOLS/upgrade_tool wl 256 boot/u-boot.img || exit 1
    $TOOLS/upgrade_tool rd || exit 1
fi

# create partition
if [[ ! -z $DISK && ! -z $XFCE ]]; then
    echo -e "\e[0;31m------ WARNING !!! disk structure will be changed /dev/${DISK}\x1B[0m"
    echo -e "\e[0;37m------ press [Enter] key to start\x1B[0m"
    read -p ""
    [[ -b /dev/${DISK} ]] && echo -e "\no\nn\np\n1\n2048\n\nw" | fdisk /dev/${DISK}
    sleep 1
fi

# flash image
if [ "$XFCE" = "true" ]; then
    echo "------ flash linuxroot ${ROOTFS_XFCE}.img"
    dd bs=1M if=${ROOTFS_XFCE}.img of=/dev/${DISK}1 conv=notrunc || exit 1
elif [ "$XFCE" = "false" ]; then
    echo "------ flash linuxroot ${ROOTFS}.img"
    dd bs=1M if=${ROOTFS}.img of=/dev/${DISK}1 conv=notrunc || exit 1
fi
