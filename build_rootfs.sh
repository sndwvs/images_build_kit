#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

get_name_rootfs() {
    # name for rootfs image
    image_type="$1"
    kernel_version KERNEL_VERSION

    if [[ $image_type == mini ]]; then
        ROOTFS="${ROOTFS_NAME/rootfs/base-rootfs}-$KERNEL_VERSION-$BOARD_NAME-build-$ROOTFS_VERSION"
    else
        if [[ $ARCH == arm ]]; then
            # Slackware ARM
            ROOTFS_XFCE="${ROOTFS_NAME/miniroot/xfce}-$KERNEL_VERSION-$BOARD_NAME-build-$ROOTFS_VERSION"
        else
            # slarm64
            ROOTFS_XFCE="${ROOTFS_NAME/rootfs/xfce-rootfs}-$KERNEL_VERSION-$BOARD_NAME-build-$ROOTFS_VERSION"
        fi
    fi
}


clean_rootfs() {
    image_type=$1

    if [[ $image_type == mini ]] && [[ ! -z $ROOTFS ]] && [[ -d $SOURCE/$ROOTFS ]]; then
        message "" "clean" "$ROOTFS"
        rm -rf $SOURCE/$ROOTFS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $image_type == xfce ]] && [[ ! -z $ROOTFS_XFCE ]] && [[ -d $SOURCE/$ROOTFS_XFCE ]] ;then
        message "" "clean" "$ROOTFS_XFCE"
        rm -rf $SOURCE/$ROOTFS_XFCE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


download_rootfs() {
    message "" "download" "$ROOTFS_NAME"
    wget -c --no-check-certificate $URL_ROOTFS/$ROOTFS_NAME.tar.xz -O $SOURCE/$ROOTFS_NAME.tar.xz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


prepare_rootfs() {
    message "" "prepare" "$ROOTFS"
    mkdir -p $SOURCE/$ROOTFS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    tar xpf $SOURCE/$ROOTFS_NAME.tar.xz -C "$SOURCE/$ROOTFS" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "install" "kernel for $ROOTFS"
    ROOT=$SOURCE/$ROOTFS upgradepkg --install-new $BUILD/$PKG/*${SOCFAMILY}*${KERNEL_VERSION}*.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ ! -z $TOOLS_PACK ]] && [[ $SOCFAMILY == sun* ]]; then
        message "" "install" "${SUNXI_TOOLS}"
        ROOT=$SOURCE/$ROOTFS upgradepkg --install-new $BUILD/$PKG/*${SUNXI_TOOLS}*.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_fstab() {
    if [[ ! $(cat $SOURCE/$ROOTFS/etc/fstab | grep $ROOT_DISK) ]];then
        message "" "setting" "fstab"
        sed -i "s:# tmpfs:tmpfs:" $SOURCE/$ROOTFS/etc/fstab
        [[ $SOCFAMILY == bcm2* ]] && echo "/dev/mmcblk0p1    /boot      vfat    defaults       0       1" >> $SOURCE/$ROOTFS/etc/fstab
        echo "/dev/$ROOT_DISK    /          ext4    noatime,nodiratime,data=writeback,errors=remount-ro       0       1" >> $SOURCE/$ROOTFS/etc/fstab || exit 1
    fi
}


setting_debug() {
    message "" "setting" "uart debugging"
    sed -e 's/#\(ttyS[0-2]\)/\1/' \
        -e '/#ttyS3/{n;/^#/i ttyFIQ0
             }' \
        -e '/#ttyp7/{n;/^#/i ttyAMA0
             }' \
        -i "$SOURCE/$ROOTFS/etc/securetty"

    sed -e 's/^\(s\(0\)\)\(.*\)\(115200\)\(.*\)\(ttyS0\)/\1\3'$SERIAL_CONSOLE' '$SERIAL_CONSOLE_SPEED'/' \
        -i "$SOURCE/$ROOTFS/etc/inittab"
}


setting_motd() {
    message "" "setting" "motd message"
    # http://patorjk.com/ font: rectangles
    [[ -f "$CWD/config/boards/$BOARD_NAME/motd" ]] && install -m644 -D "$CWD/config/boards/$BOARD_NAME/motd" "$SOURCE/$ROOTFS/etc/motd"
}


setting_rc_local() {
    message "" "setting" "rc.local"
    cat <<EOF >"$SOURCE/$ROOTFS/etc/rc.d/rc.local"
#!/bin/sh
#
# /etc/rc.d/rc.local:  Local system initialization script.
#
# Put any local setup commands in here:

echo "Running script \$0:"

# Find out how we were called.
case "\$0" in
        *local|*M) # if booting name script rc.M
                command="start"
                ;;
        *local_shutdown)
                command="stop"
                ;;
        *)
                echo "\$0: call me as \"rc.local_shutdown\" or \"rc.local\" please!"
                exit 1
                ;;
esac


if [ -x /etc/rc.d/rc.settings ]; then
  . /etc/rc.d/rc.settings
fi
EOF

        ln -s "$SOURCE/$ROOTFS/etc/rc.d/rc.local" \
           -r "$SOURCE/$ROOTFS/etc/rc.d/rc.local_shutdown"

}


setting_wifi() {
#    if [[ ! -f "$CWD/blobs/$BOARD_NAME/rc.wifi" ]]; then
#        return 0
#    fi

    message "" "setting" "wifi"
#    install -m755 -D "$CWD/blobs/$BOARD_NAME/rc.wifi" "$SOURCE/$ROOTFS/etc/rc.d/rc.wifi"

    # fix wifi driver
    if [[ $SOCFAMILY != rk3288 && $KERNEL_SOURCE != next ]]; then
        sed -i "s#wext#nl80211#" $SOURCE/$ROOTFS/etc/rc.d/rc.inet1.conf >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

#    if [[ ! $(cat $SOURCE/$ROOTFS/etc/rc.d/rc.local | grep wifi) ]]; then
        # add start wifi boot
#        cat <<EOF >>"$SOURCE/$ROOTFS/etc/rc.d/rc.local"
#
#if [ -x /etc/rc.d/rc.wifi ] ; then
#  . /etc/rc.d/rc.wifi \$command
#fi
#EOF
#    fi
}


setting_firstboot() {
    if [[ ! -x $SOURCE/$ROOTFS/tmp/firstboot ]]; then
        message "" "setting" "firstboot"
        # add start wifi boot
        install -m755 -D "$CWD/scripts/firstboot" "$SOURCE/$ROOTFS/tmp/firstboot"
    fi

    # add root password
    sed -i "s#password#$(openssl passwd -1 password)#" "$SOURCE/$ROOTFS/tmp/firstboot"

    # resize fs
    sed -i "s#mmcblk[0-9]p[0-9]#$ROOT_DISK#" "$SOURCE/$ROOTFS/tmp/firstboot"

    if [[ ! $(cat $SOURCE/$ROOTFS/etc/rc.d/rc.local | grep firstboot) ]]; then
        cat <<EOF >>"$SOURCE/$ROOTFS/etc/rc.d/rc.local"

if [ -x /tmp/firstboot ]; then
  . /tmp/firstboot \$command
fi
EOF
    fi
}


create_img() {

    [[ $SOCFAMILY == bcm2* ]] && create_img_rpi "$1" && return 1

    if [[ $1 == xfce ]]; then
        IMAGE="$ROOTFS_XFCE"
    else
        IMAGE="$ROOTFS"
    fi

    # +800M for create swap firstrun
    ROOTFS_SIZE=$(rsync -an --stats $SOURCE/$IMAGE test | grep "Total file size" | sed 's/[^0-9]//g' | xargs -I{} expr {} / $((1024*1024)) + 1000)"M"

    message "" "create" "image size $ROOTFS_SIZE"

    dd if=/dev/zero of=$SOURCE/$IMAGE.img bs=1 count=0 seek=$ROOTFS_SIZE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    LOOP=$(losetup -f)

    losetup $LOOP $SOURCE/$IMAGE.img || exit 1

    write_uboot $LOOP

    message "" "create" "partition"
    echo -e "\no\nn\np\n1\n$IMAGE_OFFSET\n\nw" | fdisk $LOOP >> $LOG 2>&1 || true

    partprobe $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    losetup -d $LOOP

    # device is busy
    sleep 2

    # $IMAGE_OFFSET (start) x 512 (block size) = where to mount partition
    losetup -o $(($IMAGE_OFFSET*512)) $LOOP $SOURCE/$IMAGE.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "create" "filesystem"
    mkfs.ext4 -F -m 0 -L linuxroot $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "tune" "filesystem"
    tune2fs -o journal_data_writeback $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    tune2fs -O ^has_journal $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    e2fsck -yf $LOOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "create" "mount point and mount image"
    mkdir -p $SOURCE/image
    mount $LOOP $SOURCE/image
    rsync -a "$SOURCE/$IMAGE/" "$SOURCE/image/"
    umount $SOURCE/image
    if [[ -d $SOURCE/image ]]; then
        rm -rf $SOURCE/image
    fi
    losetup -d $LOOP

    if [[ -f $SOURCE/$IMAGE.img ]]; then
        mv $SOURCE/$IMAGE.img $BUILD/$OUTPUT/$IMAGES
    fi

    message "" "done" "image $IMAGE"
}


setting_settings() {
    if [[ ! -f "$SOURCE/$ROOTFS/etc/rc.d/rc.settings" ]];then
        message "" "setting" "rc.settings"

        if [[ "$KERNEL_SOURCE" == "next" && "$BOARD_NAME" == "cubietruck" ]];then
            cat <<EOF >>"$SOURCE/$ROOTFS/etc/rc.d/rc.settings"
#!/bin/sh

LED="/sys/class/leds"

#echo "heartbeat" > \$LED/cubietruck:blue:usr/trigger
echo "mmc0" > \$LED/cubietruck:green:usr/trigger
echo "cpu1" > \$LED/cubietruck:orange:usr/trigger
echo "cpu0" > \$LED/cubietruck:white:usr/trigger


# cpufreq
CORES=\$(cat /proc/cpuinfo | grep processor | wc -l)
core=0

#while [ \$core -lt \$CORES ]; do
#    echo performance > /sys/devices/system/cpu/cpu\$core/cpufreq/scaling_governor
#    echo 1008000 > /sys/devices/system/cpu/cpu\$core/cpufreq/scaling_max_freq
#    echo 912000 > /sys/devices/system/cpu/cpu\$core/cpufreq/scaling_min_freq
#    core=\$((\$core+1))
#done

# ondemand
while [ \$core -lt \$CORES ]; do
    echo ondemand > /sys/devices/system/cpu/cpu\$core/cpufreq/scaling_governor
    echo 1008000 > /sys/devices/system/cpu/cpu\$core/cpufreq/scaling_max_freq
    echo 336000 > /sys/devices/system/cpu/cpu\$core/cpufreq/scaling_min_freq
    core=\$((\$core+1))
done

echo 40 > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
echo 200000 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate

EOF
        fi

        if [[ -f "$SOURCE/$ROOTFS/etc/rc.d/rc.settings" ]];then
            chmod 755 "$SOURCE/$ROOTFS/etc/rc.d/rc.settings"
        fi
    fi
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
            PKG_NAME=($(wget --no-check-certificate -q -O - ${url}/${category}/ | cut -f7 -d '>' | cut -f1 -d '<' | egrep -o "(^$(echo $pkg | sed 's/+/\\\+/g'))-.*(t.z)" | sort -ur))
            for raw in ${PKG_NAME[*]};do
               [[ $(echo $raw | rev | cut -d '-' -f4- | rev | grep -ox $pkg) ]] && _PKG_NAME=$raw
            done

            [[ -z ${_PKG_NAME} ]] && ( echo "empty download package ${category}/$pkg" >> $LOG 2>&1 && message "err" "details" && exit 1 )

            message "" "download" "package $category/${_PKG_NAME}"
            wget --no-check-certificate -c -nc -nd -np ${url}/${category}/${_PKG_NAME} -P $BUILD/$PKG/${type}/${ARCH}/${category}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            unset _PKG_NAME
        fi
    done
}


install_pkg(){
    if [[ $1 == mini ]]; then
        local ROOTFS="$ROOTFS"
    else
        local ROOTFS="$ROOTFS_XFCE"
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
            ROOT=$SOURCE/$ROOTFS upgradepkg --install-new $BUILD/$PKG/${type}/${ARCH}/$category/${pkg}-* >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    done
}


setting_default_theme_xfce() {
    if [[ ! -d "$SOURCE/$ROOTFS_XFCE/etc/skel/.config/xfce4" ]];then
        message "" "setting" "default settings xfce"
        rsync -a "$CWD/config/xfce/" "$SOURCE/$ROOTFS_XFCE/etc/skel/" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        rsync -a "$CWD/config/xfce/" "$SOURCE/$ROOTFS_XFCE/root/" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_default_start_x() {
    sed "s#id:3#id:4#" -i $SOURCE/$ROOTFS_XFCE/etc/inittab

    # fix default xfce
    ln -sf $SOURCE/$ROOTFS_XFCE/etc/X11/xinit/xinitrc.xfce \
       -r $SOURCE/$ROOTFS_XFCE/etc/X11/xinit/xinitrc

    if [[ $SOCFAMILY == rk3288 ]]; then
        if [[ ! $(cat $SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.local | grep fbset) ]];then
            # add start fbset for DefaultDepth 24
            cat <<EOF >>"$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.local"

if [ -x /etc/rc.d/rc.fbset ] ; then
    /etc/rc.d/rc.fbset
fi
EOF
        fi
    fi
}


setting_for_desktop() {
    # correcting the sound output through the alsa
    #if [ ! -x "$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.pulseaudio" ]; then
    #    chmod 755 "$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.pulseaudio"
    #fi

    if [[ $SOCFAMILY == sun* ]]; then
        # adjustment for vdpau
        sed -i 's#sunxi_ve_mem_reserve=0#sunxi_ve_mem_reserve=128#' "$SOURCE/$ROOTFS_XFCE/boot/boot.cmd"
        $SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A arm -T script -d $SOURCE/$ROOTFS_XFCE/boot/boot.cmd \
        "$SOURCE/$ROOTFS_XFCE/boot/boot.scr" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_move_to_internal() {
    message "" "save" "bootloader data for move to nand"
    rsync -ar $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/ $SOURCE/$ROOTFS/boot >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "setting" "setup.sh move to nand"
    install -m755 -D "$CWD/scripts/setup.sh" "$SOURCE/$ROOTFS/root/setup.sh"

    if [[ ! $(cat $SOURCE/$ROOTFS/root/.bashrc 2>&1 | grep setup.sh) ]];then
        cat <<EOF >$SOURCE/$ROOTFS/root/.bashrc
alias setup='/root/setup.sh'
EOF
    fi

    if [[ ! $(cat $SOURCE/$ROOTFS/root/.bash_profile 2>&1 | grep setup.sh) ]];then
        cat <<EOF >$SOURCE/$ROOTFS/root/.bash_profile
source ~/.bashrc
EOF
    fi
}


setting_first_login() {
    message "" "setting" "first login"
    install -m755 -D "$CWD/scripts/check_first_login.sh" "$SOURCE/$ROOTFS/etc/profile.d/check_first_login.sh"
    touch "$SOURCE/$ROOTFS/root/.never_logged"
}


setting_issue() {
    message "" "setting" "issue message"
    install -m644 -D "$CWD/config/issue" "$SOURCE/$ROOTFS/etc/issue"
}


setting_alsa() {
    [[ ! -z "$1" ]] && local ROOTFS="$1"

    message "" "setting" "default alsa"
    chmod 644 "$SOURCE/$ROOTFS/etc/rc.d/rc.pulseaudio" || exit 1
    chmod 755 "$SOURCE/$ROOTFS/etc/rc.d/rc.alsa" || exit 1
    mv "$SOURCE/$ROOTFS/etc/asound.conf" "$SOURCE/$ROOTFS/etc/asound.conf.new" || exit 1
}


setting_sysctl() {
    message "" "setting" "sysctl"
    cat <<EOF >$SOURCE/$ROOTFS/etc/sysctl.d/ext4_tune.conf
vm.dirty_writeback_centisecs = 100
vm.dirty_expire_centisecs = 100
EOF
}


setting_udev() {
    if [[ -d $CWD/config/udev/$SOCFAMILY ]]; then
        message "" "setting" "udev"
        install -m644 -D $CWD/config/udev/$SOCFAMILY/* -t $SOURCE/$ROOTFS/etc/udev/rules.d/
    fi
}


setting_hostname() {
    message "" "setting" "hostname"
    echo $BOARD_NAME | sed 's/_/-/g' > "$SOURCE/$ROOTFS/etc/HOSTNAME"
}


install_scripts() {
    if [[ -d $CWD/scripts/$SOCFAMILY ]]; then
        message "" "install" "scripts"
        install -d $SOURCE/$ROOTFS/usr/local/bin
        install -m755 -D $CWD/scripts/$SOCFAMILY/* -t $SOURCE/$ROOTFS/usr/local/bin
    fi
}


create_initrd() {
    if [[ $MARCH == "x86_64" ]]; then
        [[ $SOCFAMILY == bcm2* ]] && find "$SOURCE/$ROOTFS/boot/" -type l -exec rm -rf {} \+ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        return 1
    fi

    message "" "create" "initrd"

    kernel_version KERNEL_VERSION

    mount --bind /dev "$SOURCE/$ROOTFS/dev"
    mount --bind /proc "$SOURCE/$ROOTFS/proc"

    echo "mkinitrd -R -L -u -w 2 -c -k ${KERNEL_VERSION} -m ${INITRD_MODULES} \\" > "$SOURCE/$ROOTFS/tmp/initrd.sh"
    echo "         -s /tmp/initrd-tree -o /tmp/initrd.gz" >> "$SOURCE/$ROOTFS/tmp/initrd.sh"
    chroot "$SOURCE/$ROOTFS" /bin/bash -c 'chmod +x /tmp/initrd.sh > /dev/null 2>&1 && /tmp/initrd.sh > /dev/null 2>&1'

    pushd "$SOURCE/$ROOTFS/tmp/initrd-tree/" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    echo "initrd-${KERNEL_VERSION}" > "$SOURCE/$ROOTFS/tmp/initrd-tree/initrd-name"
    find . | cpio --quiet -H newc -o | gzip -9 -n > "$SOURCE/$ROOTFS/tmp/initrd-${KERNEL_VERSION}.img" 2>/dev/null
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    mkimage -A $KARCH -O linux -T ramdisk -C gzip  -n 'uInitrd' -d "$SOURCE/$ROOTFS/tmp/initrd-${KERNEL_VERSION}.img" "$SOURCE/$ROOTFS/boot/uInitrd-${KERNEL_VERSION}" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    rm -rf $SOURCE/$ROOTFS/tmp/initrd* >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    umount "$SOURCE/$ROOTFS/proc"
    umount "$SOURCE/$ROOTFS/dev"

    if [[ $SOCFAMILY == bcm2* ]]; then
        cp -a "$SOURCE/$ROOTFS/boot/uInitrd-${KERNEL_VERSION}" "$SOURCE/$ROOTFS/boot/uInitrd" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    else
        ln -sf "$SOURCE/$ROOTFS/boot/uInitrd-${KERNEL_VERSION}" -r "$SOURCE/$ROOTFS/boot/uInitrd" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    install -m755 -D "$CWD/scripts/rebuild-initrd.sh" "$SOURCE/$ROOTFS/boot/rebuild-initrd.sh" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

