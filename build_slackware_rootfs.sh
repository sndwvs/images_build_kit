#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

get_name_rootfs() {
    # name for rootfs image
    image_type=$1
    kernel_version KERNEL_VERSION

    if [[ $image_type == mini ]]; then
        ROOTFS="$ROOTFS_NAME-$KERNEL_VERSION-$BOARD_NAME-build-$ROOTFS_VERSION"
    else
        ROOTFS_XFCE="$(echo $ROOTFS_NAME | sed 's#miniroot#xfce#')-$KERNEL_VERSION-$BOARD_NAME-build-$ROOTFS_VERSION"
    fi
}


clean_rootfs() {
    image_type=$1

    if [[ $image_type == mini ]] && [[ ! -z $ROOTFS ]] && [[ -d $CWD/$BUILD/$SOURCE/$ROOTFS ]]; then
        message "" "clean" "$ROOTFS"
        rm -rf $CWD/$BUILD/$SOURCE/$ROOTFS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $image_type == xfce ]] && [[ ! -z $ROOTFS_XFCE ]] && [[ -d $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE ]] ;then
        message "" "clean" "$ROOTFS_XFCE"
        rm -rf $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


download_rootfs() {
    message "" "download" "$ROOTFS_NAME"
    wget -c --no-check-certificate $URL_ROOTFS/$ROOTFS_NAME.tar.xz -O $CWD/$BUILD/$SOURCE/$ROOTFS_NAME.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


prepare_rootfs() {
    message "" "prepare" "$ROOTFS"
    mkdir -p $CWD/$BUILD/$SOURCE/$ROOTFS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    tar xpf $CWD/$BUILD/$SOURCE/$ROOTFS_NAME.tar.xz -C "$CWD/$BUILD/$SOURCE/$ROOTFS" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "install" "kernel for $ROOTFS"
    installpkg --root $CWD/$BUILD/$SOURCE/$ROOTFS $CWD/$BUILD/$PKG/*${SOCFAMILY}*${KERNEL_VERSION}*.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ ! -z $TOOLS_PACK ]] && [[ $SOCFAMILY == sun* ]]; then
        message "" "install" "${SUNXI_TOOLS}"
        installpkg --root $CWD/$BUILD/$SOURCE/$ROOTFS $CWD/$BUILD/$PKG/*${SUNXI_TOOLS}*.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_fstab() {
    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab | grep $ROOT_DISK) ]];then
        message "" "setting" "fstab"
        sed -i "s:# tmpfs:tmpfs:" $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab
        echo "/dev/$ROOT_DISK    /          ext4    noatime,nodiratime,data=writeback,errors=remount-ro       0       1" >> $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab || exit 1
    fi
}


setting_debug() {
    message "" "setting" "uart debugging"
    sed 's/#\(ttyS[1-2]\)/\1/' -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/securetty"
    sed -e 's/^\(s0:\)\(.*\)\(115200\)/\1\2'$SERIAL_CONSOLE_SPEED'/' \
        \
        -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/inittab"
#        -e 's/#\(s\([1-2]\)\)\(.*\)\(ttyS[0-1]\)\(.*\)\(9600\)/\1\3ttyS\2 '$SERIAL_CONSOLE_SPEED'/' \
    if [[ $SOCFAMILY == rk3288 ]] && [[ $KERNEL_SOURCE != next ]]; then
        sed '/vt100/{n;/^$/i f0:12345:respawn:/sbin/agetty '$SERIAL_CONSOLE_SPEED' ttyFIQ0 vt100
             }' -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/inittab"
        sed '/#ttyS3/{n;/^#/i ttyFIQ0
             }' -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/securetty"
    fi
}


setting_motd() {
    message "" "setting" "motd message"
    # http://patorjk.com/ font: rectangles
    [[ -f "$CWD/config/boards/$BOARD_NAME/motd" ]] && install -m644 -D "$CWD/config/boards/$BOARD_NAME/motd" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/motd"
}


setting_rc_local() {
    message "" "setting" "rc.local"
    cat <<EOF >"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local"
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


# start pppd c 20130914
if [ -x /etc/rc.d/rc.netd ]; then
    /etc/rc.d/rc.netd
fi

if [ -x /etc/rc.d/rc.pun ]; then
  . /etc/rc.d/rc.pun \$command
fi

if [ -x /etc/rc.d/rc.settings ]; then
  . /etc/rc.d/rc.settings
fi
EOF

        ln -s "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local" \
           -r "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local_shutdown"

}


setting_wifi() {
#    if [[ ! -f "$CWD/bin/$BOARD_NAME/rc.wifi" ]]; then
#        return 0
#    fi

    message "" "setting" "wifi"
#    install -m755 -D "$CWD/bin/$BOARD_NAME/rc.wifi" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.wifi"

    # fix wifi driver
    [[ $SOCFAMILY == rk3288 && $KERNEL_SOURCE != next ]] && sed -i "s#wext#nl80211#" $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.inet1.conf

#    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local | grep wifi) ]]; then
        # add start wifi boot
#        cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local"
#
#if [ -x /etc/rc.d/rc.wifi ] ; then
#  . /etc/rc.d/rc.wifi \$command
#fi
#EOF
#    fi
}


setting_firstboot() {
    if [[ ! -x $CWD/$BUILD/$SOURCE/$ROOTFS/tmp/firstboot ]]; then
        message "" "setting" "firstboot"
        # add start wifi boot
        install -m755 -D "$CWD/scripts/firstboot" "$CWD/$BUILD/$SOURCE/$ROOTFS/tmp/firstboot"
    fi

    # add root password
    sed -i "s#password#$(openssl passwd -1 password)#" "$CWD/$BUILD/$SOURCE/$ROOTFS/tmp/firstboot"

    # resize fs
    sed -i "s#mmcblk[0-9]p[0-9]#$ROOT_DISK#" "$CWD/$BUILD/$SOURCE/$ROOTFS/tmp/firstboot"

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local | grep firstboot) ]]; then
        cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local"

if [ -x /tmp/firstboot ]; then
  . /tmp/firstboot \$command
fi
EOF
    fi
}


setting_dhcpcd() {
    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/dhcpcd.conf | grep nolink) ]]; then
        message "" "setting" "dhcpcd.conf"
        cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/dhcpcd.conf"
noarp
nolink

EOF
    fi
}


create_img() {

    if [[ $1 == xfce ]]; then
        IMAGE="$ROOTFS_XFCE"
    else
        IMAGE="$ROOTFS"
    fi

    # +800M for create swap firstrun
    ROOTFS_SIZE=$(expr $(du -sH $CWD/$BUILD/$SOURCE/$IMAGE | awk '{print $1}') / 1024 + 800)"M"

    message "" "create" "image size $ROOTFS_SIZE"

    dd if=/dev/zero of=$CWD/$BUILD/$SOURCE/$IMAGE.img bs=1 count=0 seek=$ROOTFS_SIZE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    LOOP=$(losetup -f)

    losetup $LOOP $CWD/$BUILD/$SOURCE/$IMAGE.img || exit 1

    write_uboot $LOOP

    message "" "create" "partition"
    echo -e "\no\nn\np\n1\n$IMAGE_OFFSET\n\nw" | fdisk $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || true

    partprobe $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    losetup -d $LOOP

    # device is busy
    sleep 2

    # $IMAGE_OFFSET (start) x 512 (block size) = where to mount partition
    losetup -o $(($IMAGE_OFFSET*512)) $LOOP $CWD/$BUILD/$SOURCE/$IMAGE.img >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "create" "filesystem"
    mkfs.ext4 -F -m 0 -L linuxroot $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "tune" "filesystem"
    tune2fs -o journal_data_writeback $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    tune2fs -O ^has_journal $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    e2fsck -yf $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    message "" "create" "mount point and mount image"
    mkdir -p $CWD/$BUILD/$SOURCE/image
    mount $LOOP $CWD/$BUILD/$SOURCE/image
    rsync -a "$CWD/$BUILD/$SOURCE/$IMAGE/" "$CWD/$BUILD/$SOURCE/image/"
    umount $CWD/$BUILD/$SOURCE/image
    if [[ -d $CWD/$BUILD/$SOURCE/image ]]; then
        rm -rf $CWD/$BUILD/$SOURCE/image
    fi
    losetup -d $LOOP

    if [[ -f $CWD/$BUILD/$SOURCE/$IMAGE.img ]]; then
        mv $CWD/$BUILD/$SOURCE/$IMAGE.img $CWD/$BUILD/$OUTPUT/$FLASH
    fi

    message "" "done" "image $IMAGE"
}


setting_settings() {
    if [[ ! -f "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.settings" ]];then
        message "" "setting" "rc.settings"

        if [[ "$KERNEL_SOURCE" == "next" && "$BOARD_NAME" == "cubietruck" ]];then
            cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.settings"
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

        if [[ -f "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.settings" ]];then
            chmod 755 "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.settings"
        fi
    fi
}


download_pkg() {
    # get parameters
    local url=$1
    local type=$2
    eval packages=\$${type}

    for pkg in ${packages}; do
        category=$(echo $pkg | cut -f1 -d "/")
        pkg=$(echo $pkg | cut -f2 -d "/")
        if [[ ! -z ${pkg} ]];then
            PKG_NAME=($(wget -q -O - ${url}/${category}/ | cut -f2 -d '>' | cut -f1 -d '<' | egrep -o "(^$(echo $pkg | sed 's/+/\\\+/g'))-.*(t.z)" | sort -ur))
            for raw in ${PKG_NAME[*]};do
               [[ $(echo $raw | rev | cut -d '-' -f4- | rev | grep -ox $pkg) ]] && _PKG_NAME=$raw
            done

            [[ -z ${_PKG_NAME} ]] && ( echo "empty download package ${category}/$pkg" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 && message "err" "details" && exit 1 )

            message "" "download" "package $category/${_PKG_NAME}"
            wget -c -nc -nd -np ${url}/${category}/${_PKG_NAME} -P $CWD/$BUILD/$PKG/${type}/${ARCH}/${category}/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
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
    eval packages=\$${type}

    for pkg in ${packages}; do
        category=$(echo $pkg | cut -f1 -d "/")
        pkg=$(echo $pkg | cut -f2 -d "/")
        if [[ ! -z ${pkg} ]];then
            message "" "install" "package $category/${pkg}"
            installpkg --root $CWD/$BUILD/$SOURCE/$ROOTFS $CWD/$BUILD/$PKG/${type}/${ARCH}/$category/${pkg}-* >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    done
}


setting_default_theme_xfce() {
    if [[ ! -d "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/skel/.config/xfce4" ]];then
        message "" "setting" "default settings xfce"
        rsync -a "$CWD/config/xfce/" "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/skel/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        rsync -a "$CWD/config/xfce/" "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/root/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_default_start_x() {
    sed "s#id:3#id:4#" -i $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/inittab

    # fix default xfce
    ln -sf $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/X11/xinit/xinitrc.xfce \
       -r $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/X11/xinit/xinitrc

    if [[ $SOCFAMILY == rk3288 ]]; then
        if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.local | grep fbset) ]];then
            # add start fbset for DefaultDepth 24
            cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.local"

if [ -x /etc/rc.d/rc.fbset ] ; then
    /etc/rc.d/rc.fbset
fi
EOF
        fi
    fi
}


setting_for_desktop() {
    # correcting the sound output through the alsa
    #if [ ! -x "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.pulseaudio" ]; then
    #    chmod 755 "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.pulseaudio"
    #fi

    if [[ $SOCFAMILY == sun* ]]; then
        # adjustment for vdpau
        sed -i 's#sunxi_ve_mem_reserve=0#sunxi_ve_mem_reserve=128#' "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.cmd"
        $CWD/$BUILD/$SOURCE/$BOOT_LOADER/tools/mkimage -C none -A arm -T script -d $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.cmd \
        "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.scr" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_move_to_internal() {
    message "" "setting" "data move to nand"
#    install -m755 -D "$CWD/bin/$BOARD_NAME/setup.sh" "$CWD/$BUILD/$SOURCE/$ROOTFS/root/setup.sh"
    install -m755 -D "$CWD/scripts/setup.sh" "$CWD/$BUILD/$SOURCE/$ROOTFS/root/setup.sh"

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/issue 2>&1 | grep setup.sh) ]];then
        cat <<EOF >$CWD/$BUILD/$SOURCE/$ROOTFS/etc/issue

[0;36m=======================================================================[0;39m

if you want to transfer the system to SD card to internal memory (eMMC or NAND),
follow [1;36msetup[0;39m

login: root
password: password

[0;36m=======================================================================[0;39m

Slackware GNU/\s (\l)
Kernel \r (\m)

EOF
    fi

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/root/.bashrc 2>&1 | grep setup.sh) ]];then
        cat <<EOF >$CWD/$BUILD/$SOURCE/$ROOTFS/root/.bashrc
alias setup='/root/setup.sh'
EOF
    fi

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/root/.bash_profile 2>&1 | grep setup.sh) ]];then
        cat <<EOF >$CWD/$BUILD/$SOURCE/$ROOTFS/root/.bash_profile
source ~/.bashrc
EOF
    fi
}


setting_first_login() {
    message "" "setting" "first login"
    install -m755 -D "$CWD/scripts/check_first_login.sh" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/profile.d/check_first_login.sh"
    touch "$CWD/$BUILD/$SOURCE/$ROOTFS/root/.never_logged"
}


setting_issue() {
    message "" "setting" "issue message"
    install -m644 -D "$CWD/config/issue" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/issue"
}


setting_alsa() {
    [[ ! -z "$1" ]] && local ROOTFS="$1"

    message "" "setting" "default alsa"
    chmod 644 "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.pulseaudio" || exit 1
    chmod 755 "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.alsa" || exit 1
    mv "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/asound.conf" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/asound.conf.new" || exit 1
}


setting_sysctl() {
    message "" "setting" "sysctl"
    cat <<EOF >$CWD/$BUILD/$SOURCE/$ROOTFS/etc/sysctl.d/ext4_tune.conf
vm.dirty_writeback_centisecs = 100
vm.dirty_expire_centisecs = 100
EOF
}


setting_udev() {
    message "" "setting" "udev"
    install -m644 -D "$CWD/config/91-usb-power.rules" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/udev/rules.d/91-usb-power.rules"
}


setting_h3dmode() {
    message "" "setting" "h3dmode"
    install -m755 -D "$CWD/scripts/h3dmode" "$CWD/$BUILD/$SOURCE/$ROOTFS/sbin/h3dmode"
}


setting_hostname() {
    message "" "setting" "hostname"
    echo $BOARD_NAME | sed 's/_/-/g' > "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/HOSTNAME"
}


