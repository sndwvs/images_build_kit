#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

get_name_rootfs() {
    # name for rootfs image
    image_type="$1"
    KERNEL_VERSION=$(get_version $SOURCE/$KERNEL_DIR)

    if [[ $image_type == server || $image_type == core ]]; then
        ROOTFS="${ROOTFS_NAME}-${ARCH}-${image_type}-$BOARD_NAME-$KERNEL_VERSION-build-${ROOTFS_VERSION}"
    else
        ROOTFS_DESKTOP="${ROOTFS_NAME}-${ARCH}-${image_type}-$BOARD_NAME-$KERNEL_VERSION-build-${ROOTFS_VERSION}"
    fi
}


clean_rootfs() {
    image_type="$1"

    if [[ $image_type == server || $image_type == core ]] && [[ ! -z $ROOTFS ]] && [[ -d $SOURCE/$ROOTFS ]]; then
        message "" "clean" "$ROOTFS"
        rm -rf $SOURCE/$ROOTFS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $image_type != server ]] && [[ ! -z $ROOTFS_DESKTOP ]] && [[ -d $SOURCE/$ROOTFS_DESKTOP ]] ;then
        message "" "clean" "$ROOTFS_DESKTOP"
        rm -rf $SOURCE/$ROOTFS_DESKTOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


prepare_rootfs() {
    message "" "prepare" "$ROOTFS"
    mkdir -p $SOURCE/$ROOTFS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


setting_fstab() {
    if [[ ! $(cat $SOURCE/$ROOTFS/etc/fstab | grep $ROOT_DISK) ]];then
        message "" "setting" "fstab"
        sed -i "s:# tmpfs:tmpfs:" $SOURCE/$ROOTFS/etc/fstab
        if [[ $DISTR == sla* ]]; then
            echo "/dev/$ROOT_DISK    /          ext4    noatime,nodiratime,data=writeback,errors=remount-ro       0       1" >> $SOURCE/$ROOTFS/etc/fstab || exit 1
            if [[ $SOCFAMILY == sun20iw1p1 && $KERNEL_SOURCE != next ]]; then
                echo "debugfs    /sys/kernel/debug      debugfs  defaults       0       0" >> $SOURCE/$ROOTFS/etc/fstab
            elif [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
                echo "/dev/${ROOT_DISK/p?/p1}    /boot      vfat    defaults       0       1" >> $SOURCE/$ROOTFS/etc/fstab
            elif [[ $SOCFAMILY == rk356* ]]; then
                echo "/dev/${ROOT_DISK/p?/p1}    /boot      ext4    noatime,nodiratime       0       1" >> $SOURCE/$ROOTFS/etc/fstab
            fi
        elif [[ $DISTR == crux* ]]; then
            sed -i 's:#\(shm\):\1:' $SOURCE/$ROOTFS/etc/fstab || exit 1
            sed -i "/\# End of file/ i \\/dev\/$ROOT_DISK    \/          ext4    noatime,nodiratime,data=writeback,errors=remount-ro       0       1\n" $SOURCE/$ROOTFS/etc/fstab || exit 1
            if [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
                sed -i "/\# End of file/ i \\/dev\/${ROOT_DISK/p?/p1}    \/boot      vfat    defaults       0       1\n" $SOURCE/$ROOTFS/etc/fstab
            elif [[ $SOCFAMILY == rk356* ]]; then
                sed -i "/\# End of file/ i \\/dev\/${ROOT_DISK/p?/p1}    \/boot      ext4    noatime,nodiratime       0       1\n" $SOURCE/$ROOTFS/etc/fstab
            fi
        fi
    fi
}


setting_debug() {
    message "" "setting" "uart debugging"
    if [[ $DISTR == sla* ]]; then
        sed -e 's/#\(ttyS[0-2]\)/\1/' \
            -e '/#ttyS3/{n;/^#/i ttyFIQ0\nttyAMA0\nttyAML0
                 }' \
            -i "$SOURCE/$ROOTFS/etc/securetty"

        sed -e "s/^#\(\(s\(1\)\).*\)\(ttyS0\).*\(9600\)/\1$SERIAL_CONSOLE $SERIAL_CONSOLE_SPEED/" \
            -i "$SOURCE/$ROOTFS/etc/inittab"
    elif [[ $DISTR == crux* ]]; then
        sed -e '/ttyS0/{n;/^/i ttyS1\nttyS2\nttyS3\nttyFIQ0\nttyAMA0\nttyAML0
                 }' \
            -i "$SOURCE/$ROOTFS/etc/securetty"

        sed -e "s/^#\(\(s\(1\)\).*\).*\(38400\).*\(ttyS0\)\(.*$\)/\1$SERIAL_CONSOLE_SPEED $SERIAL_CONSOLE\6/" \
            -i "$SOURCE/$ROOTFS/etc/inittab"
    fi
}


setting_motd() {
    message "" "setting" "motd message"
    # http://patorjk.com/ font: rectangles
    [[ -f "$CWD/config/boards/$BOARD_NAME/motd.${DISTR}" ]] && install -m644 -D "$CWD/config/boards/$BOARD_NAME/motd.${DISTR}" "$SOURCE/$ROOTFS/etc/motd"
    return 0
}


setting_wifi() {
    message "" "setting" "wifi"
    # fix wifi driver
    if [[ $SOCFAMILY != rk3288 && $KERNEL_SOURCE != next ]]; then
        sed -i "s#wext#nl80211#" $SOURCE/$ROOTFS/etc/rc.d/rc.inet1.conf >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


build_img() {
    local IMAGE="$1"

    local PART="1"

    [[ -z "$IMAGE" ]] && exit 1

    message "" "build" "image: $IMAGE"

    LOOP=$(losetup -f)

    losetup $LOOP $SOURCE/$IMAGE.img || exit 1

    message "" "create" "partition"
    if [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
        echo -e "\no\nn\np\n1\n$IMAGE_OFFSET\n+512M\n\nt\nc\nn\np\n2\n$IMAGE_OFFSET\n\n\n\nw" | fdisk $LOOP >> $LOG 2>&1 || true
        PART="2"
    else
        write_uboot $LOOP
        echo -e "\no\nn\np\n1\n$IMAGE_OFFSET\n\nw" | fdisk $LOOP >> $LOG 2>&1 || true
    fi

    partprobe $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # device is busy
    sleep 2

    message "" "create" "filesystem"
    if [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
        mkfs.vfat ${LOOP}p1 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    mkfs.ext4 -F -m 0 -L linuxroot ${LOOP}p${PART} >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "tune" "filesystem"
    tune2fs -o journal_data_writeback ${LOOP}p${PART} >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    tune2fs -O ^has_journal ${LOOP}p${PART} >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    e2fsck -yf ${LOOP}p${PART} >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "create" "mount point and mount image"

    mkdir -p $SOURCE/image
    mount ${LOOP}p${PART} $SOURCE/image
    if [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
        mkdir -p $SOURCE/image/boot
        mount ${LOOP}p1 $SOURCE/image/boot
        write_uboot $LOOP
    fi

    message "" "copy" "data to image"
    rsync -a "$SOURCE/$IMAGE/" "$SOURCE/image/"

    if [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
        umount $SOURCE/image/boot
    fi
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


download_pkg() {
    # get parameters
    local url=$1
    local type=$2
    local packages

    # read packages type
    read_packages "${type}" packages

    for pkg in ${packages}; do
        category=$(echo $pkg | cut -f1 -d "/")
        pkg=$(echo $pkg | cut -f2 -d "/")
        if [[ ! -z ${pkg} ]];then
            if [[ $USE_SLARM64_MIRROR == yes ]];then
                PKG_NAME=($(wget --no-check-certificate -q -O - ${url}/${category}/ | grep -oP '(?<=\"\>&nbsp;).*(?=\<\/a\>)' | egrep -o "(^$(echo $pkg | sed 's/+/\\\+/g'))-.*(t.z)" | sort -ur))
            else
                PKG_NAME=($(wget --no-check-certificate -q -O - ${url}/${category}/ | cut -f7 -d '>' | cut -f1 -d '<' | egrep -o "(^$(echo $pkg | sed 's/+/\\\+/g'))-.*(t.z)" | sort -ur))
            fi

            [[ $DISTR == crux* ]] && PKG_NAME=($(wget --no-check-certificate -q -O - ${url}/${category}/ | cut -f7 -d '>' | cut -f1 -d '<' | egrep -o "(^$(echo $pkg | sed 's/+/\\\+/g'))#.*(t.*z)" | sort -ur))

            for raw in ${PKG_NAME[*]};do
                if [[ $DISTR == sla* ]]; then
                   [[ $(echo $raw | rev | cut -d '-' -f4- | rev | grep -ox $pkg) ]] && _PKG_NAME=$raw
                elif [[ $DISTR == crux* ]]; then
                   [[ $(echo $raw | cut -d "#" -f1 | grep -ox $pkg) ]] && _PKG_NAME=${raw/\#/%23}
                fi
            done

            [[ -z ${_PKG_NAME} ]] && ( echo "empty download package ${category}/$pkg" >> $LOG 2>&1 && message "err" "details" && exit 1 )

            message "" "download" "package $category/${_PKG_NAME/\%23/#}"
            wget --no-check-certificate -c -nc -nd -np ${url}/${category}/${_PKG_NAME} -P $BUILD/$PKG/${type}/${ARCH}/${category}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            unset _PKG_NAME
        fi
    done
}


install_pkg(){
    if [[ $1 == server || $1 == core* || $1 == opt ]]; then
        local ROOTFS="$ROOTFS"
    else
        local ROOTFS="$ROOTFS_DESKTOP"
    fi

    local type=$1
    local packages

    # read packages type
    read_packages "${type}" packages

    for pkg in ${packages}; do
        category=$(echo $pkg | cut -f1 -d "/")
        pkg=$(echo $pkg | cut -f2 -d "/")
        if [[ ! -z ${pkg} ]];then
            message "" "install" "package $category/${pkg}"
            if [[ $DISTR == sla* ]]; then
                ROOT=$SOURCE/$ROOTFS upgradepkg --install-new $BUILD/$PKG/${type}/${ARCH}/$category/${pkg}-* >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            elif [[ $DISTR == crux* ]]; then
                [[ $type == *-update ]] && local up="-u -f"
                # fixed install packages
                [[ ! -e $SOURCE/$ROOTFS/var/lib/pkg/db ]] && ( install -Dm644 /dev/null $SOURCE/$ROOTFS/var/lib/pkg/db >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
                pkgadd ${up} --root $SOURCE/$ROOTFS $BUILD/$PKG/${type}/${ARCH}/$category/${pkg}#* >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
        fi
    done
}


install_kernel() {
    message "" "install" "kernel ${KERNEL_VERSION}"
    if [[ $DISTR == sla* ]]; then
        ROOT=$SOURCE/$ROOTFS upgradepkg --install-new $BUILD/$PKG/*${SOCFAMILY}*${KERNEL_VERSION/-/_}*.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    elif [[ $DISTR == crux* ]]; then
        rsync -av --chown=root:root $BUILD/$PKG/kernel-${SOCFAMILY}/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        rsync -av --chown=root:root $BUILD/$PKG/kernel-modules/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        rsync -av --chown=root:root $BUILD/$PKG/kernel-firmware/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        #rsync -av --chown=root:root $BUILD/$PKG/kernel-source/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_default_start_x() {
    local de="$1"
    sed "s#id:3#id:4#" -i $SOURCE/$ROOTFS_DESKTOP/etc/inittab

    # starting the desktop environment
    ln -sf $SOURCE/$ROOTFS_DESKTOP/etc/X11/xinit/xinitrc.${de} \
       -r $SOURCE/$ROOTFS_DESKTOP/etc/X11/xinit/xinitrc
}


setting_for_desktop() {
    if [[ $SOCFAMILY == sun* && -e $SOURCE/$ROOTFS_DESKTOP/boot/boot.cmd ]]; then
        # adjustment for vdpau
        sed -i 's#sunxi_ve_mem_reserve=0#sunxi_ve_mem_reserve=128#' "$SOURCE/$ROOTFS_DESKTOP/boot/boot.cmd"
        $SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A arm -T script -d $SOURCE/$ROOTFS_DESKTOP/boot/boot.cmd \
        "$SOURCE/$ROOTFS_DESKTOP/boot/boot.scr" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_bootloader_move_to_disk() {
    message "" "save" "bootloader data for move to disk"
    rsync -ar $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/ $SOURCE/$ROOTFS/boot >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


setting_system() {
    message "" "setting" "system"
    rsync -av --chown=root:root $CWD/system/overall/$DISTR/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    if [[ -d $CWD/system/$SOCFAMILY ]]; then
        rsync -av --chown=root:root $CWD/system/$SOCFAMILY/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    elif [[ -d $CWD/system/${BOARD_NAME} ]]; then
        rsync -av --chown=root:root $CWD/system/${BOARD_NAME}/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    elif [[ -d $CWD/system/${BOARD_NAME}-${KERNEL_SOURCE} ]]; then
        rsync -av --chown=root:root $CWD/system/${BOARD_NAME}-${KERNEL_SOURCE}/ $SOURCE/$ROOTFS/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    # setting for root
    if [[ -d $SOURCE/$ROOTFS/etc/skel ]]; then
        rsync -av --chown=root:root $SOURCE/$ROOTFS/etc/skel/ $SOURCE/$ROOTFS/root/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $DISTR == crux* ]]; then
        # crux-arm added firstrun as service
        sed -i 's:\(SERVICES=.*\)):\1 firstrun):g' "$SOURCE/$ROOTFS/etc/rc.conf"
        # prohibit firmware update
        sed -i '/\# End of file/ i \\nUPGRADE            \^lib\/firmware\/\.\*$          NO\n' "$SOURCE/$ROOTFS/etc/pkgadd.conf"
    fi
}


setting_alsa() {
    [[ ! -z "$1" ]] && local ROOTFS="$1"

    message "" "setting" "default alsa"
    chmod 644 "$SOURCE/$ROOTFS/etc/rc.d/rc.pulseaudio" || exit 1
    chmod 755 "$SOURCE/$ROOTFS/etc/rc.d/rc.alsa" || exit 1
    mv "$SOURCE/$ROOTFS/etc/asound.conf" "$SOURCE/$ROOTFS/etc/asound.conf.new" || exit 1
}


setting_hostname() {
    message "" "setting" "hostname"
    if [[ $DISTR == sla* ]]; then
        echo $BOARD_NAME | sed 's/_/-/g' > "$SOURCE/$ROOTFS/etc/HOSTNAME"
    elif [[ $DISTR == crux* ]]; then
        echo $BOARD_NAME | sed 's/_/-/g' | xargs -I {} sed -i 's:\(^HOSTNAME=\).*:\1{}:g' "$SOURCE/$ROOTFS/etc/rc.conf"
    fi
}


setting_networkmanager() {
    [[ ! -z "$1" ]] && local ROOTFS="$1"

    message "" "setting" "networkmanager"
    chmod 755 "$SOURCE/$ROOTFS/etc/rc.d/rc.networkmanager" || exit 1
}


setting_ntp() {
    message "" "setting" "ntp"
    if [[ $DISTR == sla* ]]; then
        chmod 755 "$SOURCE/$ROOTFS/etc/rc.d/rc.ntpd" || exit 1
        sed 's:^#server:server:g' -i "$SOURCE/$ROOTFS/etc/ntp.conf" || exit 1
    elif [[ $DISTR == crux* ]]; then
        sed 's:^#\(.*rdate.*ntp.org$\):\1:g' $SOURCE/$ROOTFS/etc/cron/daily/rdate >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


create_initrd() {
    if [[ $MARCH == "x86_64" || ( $MARCH != "riscv64" && $ARCH == "riscv64" ) ]]; then
        if [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
            find "$SOURCE/$ROOTFS/boot/" -type l -exec rm -rf {} \+ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
        return 0
    fi

    message "" "create" "initrd"

    KERNEL_VERSION=$(get_version $SOURCE/$KERNEL_DIR)

    mount --bind /dev "$SOURCE/$ROOTFS/dev"
    mount --bind /proc "$SOURCE/$ROOTFS/proc"

    echo "mkinitrd -R -L -u -w 2 -c -k ${KERNEL_VERSION} -m ${INITRD_MODULES} \\" > "$SOURCE/$ROOTFS/tmp/initrd.sh"
    echo "         -s /tmp/initrd-tree -o /tmp/initrd.gz" >> "$SOURCE/$ROOTFS/tmp/initrd.sh"
    # mkinitrd corrupted for ARM
    [[ $ARCH == arm ]] && export MKINITRD_ALLOWEXEC=yes
    chroot "$SOURCE/$ROOTFS" /bin/bash -c 'chmod +x /tmp/initrd.sh > /dev/null 2>&1 && /tmp/initrd.sh > /dev/null 2>&1'

    pushd "$SOURCE/$ROOTFS/tmp/initrd-tree/" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    echo "initrd-${KERNEL_VERSION}" > "$SOURCE/$ROOTFS/tmp/initrd-tree/initrd-name"
    find . | cpio --quiet -H newc -o | gzip -9 -n > "$SOURCE/$ROOTFS/tmp/initrd-${KERNEL_VERSION}.img" 2>/dev/null
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    mkimage -A $KARCH -O linux -T ramdisk -C gzip  -n 'uInitrd' -d "$SOURCE/$ROOTFS/tmp/initrd-${KERNEL_VERSION}.img" "$SOURCE/$ROOTFS/boot/uInitrd-${KERNEL_VERSION}" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    rm -rf $SOURCE/$ROOTFS/tmp/initrd* >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    umount "$SOURCE/$ROOTFS/proc"
    umount "$SOURCE/$ROOTFS/dev"

    if [[ $SOCFAMILY == bcm2* || $BOARD_NAME == x96_max_plus ]]; then
        cp -a "$SOURCE/$ROOTFS/boot/uInitrd-${KERNEL_VERSION}" "$SOURCE/$ROOTFS/boot/uInitrd" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        find "$SOURCE/$ROOTFS/boot/" -type l -exec rm -rf {} \+ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    else
        ln -sf "$SOURCE/$ROOTFS/boot/uInitrd-${KERNEL_VERSION}" -r "$SOURCE/$ROOTFS/boot/uInitrd" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_bootloader() {
    message "" "setting" "bootloader"
    # u-boot config
    if [[ -f $CWD/config/boot_scripts/extlinux-$SOCFAMILY.conf ]]; then
        install -Dm644 $CWD/config/boot_scripts/extlinux-$SOCFAMILY.conf "$SOURCE/$ROOTFS/boot/extlinux/extlinux.conf"
        # u-boot serial inteface config
        sed -e "s:%DISTR%:${DISTR}:g" \
            -e "s:%ROOT_DISK%:${ROOT_DISK}:g" \
            -e "s:%DEVICE_TREE_BLOB%:${DEVICE_TREE_BLOB}:g" \
            -e "s:%SERIAL_CONSOLE%:${SERIAL_CONSOLE}:g" \
            -e "s:%SERIAL_CONSOLE_SPEED%:${SERIAL_CONSOLE_SPEED}:g" \
            -i "$SOURCE/$ROOTFS/boot/extlinux/extlinux.conf"
        return 0
    fi
    if [[ -f $CWD/config/boot_scripts/boot-$SOCFAMILY.cmd ]]; then
        install -Dm644 $CWD/config/boot_scripts/boot-$SOCFAMILY.cmd "$SOURCE/$ROOTFS/boot/boot.cmd"
        # u-boot serial inteface config
        sed -e "s:%SERIAL_CONSOLE%:${SERIAL_CONSOLE}:g" \
            -e "s:%SERIAL_CONSOLE_SPEED%:${SERIAL_CONSOLE_SPEED}:g" \
            -i "$SOURCE/$ROOTFS/boot/boot.cmd"
    fi
    if [[ -f $CWD/config/boot_scripts/boot-$SOCFAMILY.ini ]];then
        install -Dm644 $CWD/config/boot_scripts/boot-$SOCFAMILY.ini "$SOURCE/$ROOTFS/boot/boot.ini"
        # u-boot serial inteface config
        sed -e "s:%SERIAL_CONSOLE%:${SERIAL_CONSOLE}:g" \
            -e "s:%SERIAL_CONSOLE_SPEED%:${SERIAL_CONSOLE_SPEED}:g" \
            -i "$SOURCE/$ROOTFS/boot/boot.ini"
    fi
    # amlogic tv box: compile boot script
    if [[ -f $CWD/config/boot_scripts/boot-${BOARD_NAME//_/-}-aml_autoscript.cmd ]]; then
        install -Dm644 $CWD/config/boot_scripts/boot-${BOARD_NAME//_/-}-aml_autoscript.cmd "$SOURCE/$ROOTFS/boot/aml_autoscript.cmd" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        $SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A $KARCH -T script -a 0 -e 0 -d $SOURCE/$ROOTFS/boot/aml_autoscript.cmd \
                                                                        "$SOURCE/$ROOTFS/boot/aml_autoscript" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    if [[ -f $CWD/config/boot_scripts/boot-${BOARD_NAME//_/-}-emmc_autoscript.cmd ]]; then
        install -Dm644 $CWD/config/boot_scripts/boot-${BOARD_NAME//_/-}-emmc_autoscript.cmd "$SOURCE/$ROOTFS/boot/emmc_autoscript.cmd" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        $SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A $KARCH -T script -a 0 -e 0 -d $SOURCE/$ROOTFS/boot/emmc_autoscript.cmd \
                                                                        "$SOURCE/$ROOTFS/boot/emmc_autoscript" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    if [[ -f $CWD/config/boot_scripts/boot-${BOARD_NAME//_/-}-s905_autoscript.cmd ]]; then
        install -Dm644 $CWD/config/boot_scripts/boot-${BOARD_NAME//_/-}-s905_autoscript.cmd "$SOURCE/$ROOTFS/boot/s905_autoscript.cmd" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        $SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A $KARCH -T script -a 0 -e 0 -d $SOURCE/$ROOTFS/boot/s905_autoscript.cmd \
                                                                        "$SOURCE/$ROOTFS/boot/s905_autoscript" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # compile boot script
    [[ -f $SOURCE/$ROOTFS/boot/boot.cmd ]] && ( $SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A $KARCH -T script -d $SOURCE/$ROOTFS/boot/boot.cmd \
                                                                        "$SOURCE/$ROOTFS/boot/boot.scr" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    # u-boot
    if [[ -f "$CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt" ]]; then
        install -Dm644 $CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt "$SOURCE/$ROOTFS/boot/uEnv.txt"
        echo "fdtfile=${DEVICE_TREE_BLOB}" >> "$SOURCE/$ROOTFS/boot/uEnv.txt"
        # parameter to configure the boot of the legacy kernel
        [[ $SOCFAMILY == meson-sm1 && ( $KERNEL_SOURCE != next && $BOARD_NAME != x96_max_plus ) ]] && echo "kernel=$KERNEL_SOURCE" >> "$SOURCE/$ROOTFS/boot/uEnv.txt"
    fi
    # change root disk if disk not default
    [[ -n ${ROOT_DISK##*mmcblk0p1} ]] && echo "rootdev=/dev/$ROOT_DISK" >> "$SOURCE/$ROOTFS/boot/uEnv.txt"
    return 0
}


setting_governor() {
    if [[ ! -z $CPU_GOVERNOR ]]; then
        message "" "setting" "governor"
        sed "s:#SCALING_\(.*\)=\(.*\):SCALING_\1=$CPU_GOVERNOR:g" -i $SOURCE/$ROOTFS/etc/default/cpufreq
    fi
}


setting_datetime() {
    message "" "setting" "datetime"
    # setting build time
    [[ -e $SOURCE/$ROOTFS/usr/local/bin/fakehwclock.sh ]] && touch $SOURCE/$ROOTFS/usr/local/bin/fakehwclock.sh || (message "err" "details" && exit 1) || exit 1

    rm -f $SOURCE/$ROOTFS/etc/localtime* >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    ln -vfs /usr/share/zoneinfo/UTC $SOURCE/$ROOTFS/etc/localtime-copied-from  >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    cp -favv $SOURCE/$ROOTFS/usr/share/zoneinfo/UTC $SOURCE/$ROOTFS/etc/localtime >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


setting_dhcp() {
    message "" "setting" "eth0 enabled dhcp"
    # set eth0 to be DHCP by default
    if [[ $DISTR == sla* ]]; then
        sed -i 's/USE_DHCP\[0\]=.*/USE_DHCP\[0\]="yes"/g' $SOURCE/$ROOTFS/etc/rc.d/rc.inet1.conf
    elif [[ $DISTR == crux* ]]; then
        echo $BOARD_NAME | sed 's/_/-/g' | xargs -I {} sed -i 's:\(^HOSTNAME=\).*:\1{}:g' "$SOURCE/$ROOTFS/etc/rc.conf"
        sed -e 's:^\(DEV=\).*:\1eth0:' -e 's:^\(DHCPOPTS=.*\)":\1 \$\{DEV\}":' -i "$SOURCE/$ROOTFS/etc/rc.d/net"
    fi
}


setting_ssh() {
    message "" "setting" "ssh login under the root"
    sed -e 's/^\(#\)\(PermitRootLogin\).*/\2 yes/g' \
        -e 's/^\(#\)\(PasswordAuth.*\)/\2/g' \
    -i "$SOURCE/$ROOTFS/etc/ssh/sshd_config"
    # crux-arm added sshd in service
    if [[ $DISTR == crux* ]]; then
        sed -i 's:\(SERVICES=.*\)\(net\)\(.*\):\1\2 sshd\3:g' "$SOURCE/$ROOTFS/etc/rc.conf"
    fi
}


setting_modules() {
    if [[ ! -z ${MODULES} ]]; then
        message "" "setting" "install modules: ${MODULES}"
        tr ' ' '\n' <<< "${MODULES}" | sed -e 's/^/\/sbin\/modprobe /' >> "$SOURCE/$ROOTFS/etc/rc.d/rc.modules.local"
    fi
    if [[ ! -z ${MODULES_BLACKLIST} ]]; then
        message "" "setting" "blacklist modules: ${MODULES_BLACKLIST}"
        tr ' ' '\n' <<< "${MODULES_BLACKLIST}" | sed -e 's/^/blacklist /' > "$SOURCE/$ROOTFS/etc/modprobe.d/blacklist-${BOARD_NAME}.conf"
    fi
}


removed_default_xorg_conf() {
    [[ ! -z "$1" ]] && local ROOTFS="$1"

    if [[ -e $SOURCE/$ROOTFS/etc/X11/xorg.conf.d/xorg.conf ]]; then
        message "" "setting" "removed default xorg.conf"
        rm -rf "$SOURCE/$ROOTFS/etc/X11/xorg.conf.d/xorg.conf" || exit 1
    fi
}


image_compression() {
    local IMG="$1"
    pushd $BUILD/$OUTPUT/$IMAGES >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    COMPRESSOR="zstd"
    EXT="zst"
    PARAMETERS="-qf12 --rm -T${CPUS}"
    message "" "compression" "$COMPRESSOR $PARAMETERS ${IMG}.img"
    pushd $BUILD/$OUTPUT/$IMAGES >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    $COMPRESSOR $PARAMETERS ${IMG}.img
    # testing
    message "" "testing" "$COMPRESSOR -qt ${IMG}.img.${EXT}"
    $COMPRESSOR -qt ${IMG}.img.${EXT}
    # create checksum
    local CHECKSUM_EXT="sha256"
    local CHECKSUM="${CHECKSUM_EXT}sum"
    message "" "create" "checksum ${CHECKSUM} ${IMG}.img.${EXT}.${CHECKSUM_EXT}"
    ${CHECKSUM} ${IMG}.img.${EXT} > ${IMG}.img.${EXT}.${CHECKSUM_EXT}
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

