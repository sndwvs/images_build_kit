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
    installpkg --root $CWD/$BUILD/$SOURCE/$ROOTFS $CWD/$BUILD/$PKG/*${KERNEL_VERSION}*.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


setting_fstab() {
    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab | grep $ROOT_DISK) ]];then
        message "" "setting" "fstab"
        sed -i "s:# tmpfs:tmpfs:" $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab
        echo "/dev/$ROOT_DISK    /          ext4    defaults,noatime,nodiratime,commit=600,errors=remount-ro       0       1" >> $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab || exit 1
    fi
}


setting_debug() {
    message "" "setting" "uart debugging"
    sed 's/#\(ttyS[1-2]\)/\1/' -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/securetty"
    sed 's/#\(s\([1-2]\)\)\(.*\)\(ttyS[0-1]\)\(.*\)\(9600\)/\1\3ttyS\2 115200/' \
        -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/inittab"
    if [[ $SOCFAMILY == rk3288 ]] && [[ $KERNEL_SOURCE != next ]]; then
	sed '/vt100/{n;/^$/i f0:12345:respawn:/sbin/agetty 115200 ttyFIQ0 vt100
	     }' -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/inittab"
    	sed '/#ttyS3/{n;/^#/i ttyFIQ0
	     }' -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/securetty"
    fi
}


setting_motd() {
    message "" "setting" "motd message"

    case "$BOARD_NAME" in
		firefly)
		cat <<EOF >"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/motd"
 ____  ____  ____  ____  ____  __   _  _    ____  _  _  ___  ___   ___  ___
( ___)(_  _)(  _ \( ___)( ___)(  ) ( \/ )  (  _ \( )/ )(__ )(__ \ ( _ )( _ ) 
 )__)  _)(_  )   / )__)  )__)  )(__ \  /    )   / )  (  (_ \ / _/ / _ \/ _ \ 
(__)  (____)(_)\_)(____)(__)  (____)(__)   (_)\_)(_)\_)(___/(____)\___/\___/ 
Slackware

EOF
		;;
		cubietruck)
	        cat <<EOF >"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/motd"
  ___  __  __  ____  ____  ____  ____  _____    __    ____  ____  
 / __)(  )(  )(  _ \(_  _)( ___)(  _ \(  _  )  /__\  (  _ \(  _ \ 
( (__  )(__)(  ) _ < _)(_  )__)  ) _ < )(_)(  /(__)\  )   / )(_) )
 \___)(______)(____/(____)(____)(____/(_____)(__)(__)(_)\_)(____/ 
Slackware

EOF
		;;
		orange_pi_plus_2e)
	        cat <<EOF >"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/motd"
 _____  ____    __    _  _  ___  ____    ____  ____    ____  __    __  __  ___    ___   ____ 
(  _  )(  _ \  /__\  ( \( )/ __)( ___)  (  _ \(_  _)  (  _ \(  )  (  )(  )/ __)  (__ \ ( ___)
 )(_)(  )   / /(__)\  )  (( (_-. )__)    )___/ _)(_    )___/ )(__  )(__)( \__ \   / _/  )__) 
(_____)(_)\_)(__)(__)(_)\_)\___/(____)  (__)  (____)  (__)  (____)(______)(___/  (____)(____)
Slackware

EOF
		;;
    esac
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
    message "" "setting" "wifi"
    install -m755 -D "$CWD/bin/$BOARD_NAME/rc.wifi" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.wifi"

    # fix wifi driver
    sed -i "s#wext#nl80211#" $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.inet1.conf

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local | grep wifi) ]]; then
        # add start wifi boot
        cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local"

if [ -x /etc/rc.d/rc.wifi ] ; then
  . /etc/rc.d/rc.wifi \$command
fi
EOF
    fi
}


setting_firstboot() {
    if [[ ! -x $CWD/$BUILD/$SOURCE/$ROOTFS/tmp/firstboot ]]; then
        message "" "setting" "firstboot"
        # add start wifi boot
        install -m755 -D "$CWD/bin/firstboot" "$CWD/$BUILD/$SOURCE/$ROOTFS/tmp/firstboot"
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
    if [ "$1" = "xfce" ]; then
        IMAGE="$ROOTFS_XFCE"
    else
        IMAGE="$ROOTFS"
    fi
    # +600M for create swap firstrun
    ROOTFS_SIZE=$(expr $(du -sH $CWD/$BUILD/$SOURCE/$IMAGE | awk '{print $1}') / 1024 + 600)"M"

    message "" "create" "image size $ROOTFS_SIZE"

    dd if=/dev/zero of=$CWD/$BUILD/$SOURCE/$IMAGE.img bs=1 count=0 seek=$ROOTFS_SIZE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    LOOP=$(losetup -f)

    losetup $LOOP $CWD/$BUILD/$SOURCE/$IMAGE.img || exit 1

    if [[ $SOCFAMILY == sun* ]]; then
        message "" "save" "$BOOT_LOADER"
        dd if="$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" of=$LOOP bs=1024 seek=8 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        message "" "create" "partition"
#       ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >/dev/null 2>&1
#       ( ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >/dev/null 2>&1 ) || true
#       ( ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 ) # || true
#        ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || true
        echo -e "\no\nn\np\n1\n2048\n\nw" | fdisk $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || true

        partprobe $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        losetup -d $LOOP

        # device is busy
        sleep 2

        # 2048 (start) x 512 (block size) = where to mount partition
        losetup -o 1048576 $LOOP $CWD/$BUILD/$SOURCE/$IMAGE.img >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    message "" "create" "filesystem"
    mkfs.ext4 -F -m 0 -L linuxroot $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

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
    for _in in "$@";do
        let "count=$count+1"
        if [[ $count = 1 ]];then
            _URL_DISTR=${_in}
        elif [[ $count = 2 ]];then
            if [[ -z ${_in} ]];then
                suffix=${_in}
            else
                suffix='_'${_in}
            fi
        elif [[ $count -ge 2 ]];then
            category=${_in}
            eval packages=\$${_in}${suffix}
            if [[ ! -z ${packages} ]];then
                for _pkg in $packages;do
                    PKG_NAME=$(wget -q -O - ${_URL_DISTR}/${category}/ | cut -f2 -d '>' | cut -f1 -d '<' | egrep -om1 "(^$(echo $_pkg | sed 's/+/\\\+/g'))-+.*(t.z)")
                    message "" "download" "package $category/$PKG_NAME"
                    wget -c -nc -nd -np ${_URL_DISTR}/${category}/$PKG_NAME -P $CWD/$BUILD/$PKG/${category}/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
                done
            fi
        fi
    done
    # clean
    count=''
    category=''
    _URL_DISTR=''
}


install_pkg(){
    if [[ $1 == mini ]]; then
        local ROOTFS="$ROOTFS"
    else
        local ROOTFS="$ROOTFS_XFCE"
    fi

    # get parameters
    for _in in "$@";do
        let "count=$count+1"
        if [[ $count = 1 ]];then
            if [[ -z ${_in} ]];then
                suffix=${_in}
            else
                suffix='_'${_in}
            fi
        elif [[ $count -gt 1 ]];then
            category=${_in}
            eval packages=\$${_in}${suffix}
            if [[ ! -z ${packages} ]];then
                for _pkg in $packages;do
                    message "" "install" "package $category/${_pkg}"
                    installpkg --root $CWD/$BUILD/$SOURCE/$ROOTFS $CWD/$BUILD/$PKG/$category/${_pkg}* >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
                done
            fi
        fi
    done
    # clean
    count=''
    category=''
    packages=''
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
    if [ ! -x "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.pulseaudio" ]; then
        chmod 755 "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/rc.d/rc.pulseaudio"
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        # adjustment for vdpau
        sed -i 's#sunxi_ve_mem_reserve=0#sunxi_ve_mem_reserve=128#' "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.cmd"
        $CWD/$BUILD/$SOURCE/$BOOT_LOADER/tools/mkimage -C none -A arm -T script -d $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.cmd \
        "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.scr" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


setting_move_to_nand() {
    message "" "setting" "data move to nand"
    install -m755 -D "$CWD/bin/$BOARD_NAME/setup.sh" "$CWD/$BUILD/$SOURCE/$ROOTFS/root/setup.sh"

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/issue 2>&1 | grep setup.sh) ]];then
        cat <<EOF >$CWD/$BUILD/$SOURCE/$ROOTFS/etc/issue

[0;36m=======================================================================[0;39m

if you want to transfer the system to SD card to internal memory (eMMC),
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
    install -m755 -D "$CWD/bin/check_first_login.sh" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/profile.d/check_first_login.sh"
    touch "$CWD/$BUILD/$SOURCE/$ROOTFS/root/.never_logged"
}


setting_issue() {
    message "" "setting" "issue message"
    install -m644 -D "$CWD/config/issue" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/issue"
}



