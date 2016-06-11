#!/bin/bash



if [ -z $CWD ];then
    exit
fi

clean_rootfs (){
    if [ -d $CWD/$BUILD/$SOURCE/$ROOTFS ];then
        message "" "clean" "$ROOTFS"
        rm -rf $CWD/$BUILD/$SOURCE/$ROOTFS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        if [ -d $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE ];then
            message "" "clean" "$ROOTFS_XFCE"
            rm -rf $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi
    fi
    mkdir -p $CWD/$BUILD/$SOURCE/$ROOTFS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
}

download_rootfs (){
    message "" "download" "$ROOTFS_NAME"
    wget -c --no-check-certificate $URL_ROOTFS/$ROOTFS_NAME.tar.xz -O $CWD/$BUILD/$SOURCE/$ROOTFS_NAME.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
}

prepare (){
    message "" "prepare" "$ROOTFS"
    tar xpf $CWD/$BUILD/$SOURCE/$ROOTFS_NAME.tar.xz -C "$CWD/$BUILD/$SOURCE/$ROOTFS" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

    message "" "install" "$ROOTFS"
    installpkg --root $CWD/$BUILD/$SOURCE/$ROOTFS $CWD/$BUILD/$PKG/*${KERNEL_VERSION}*.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
}

setting_fstab (){
    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab | grep $ROOT_DISK) ]];then
        message "" "setting" "fstab"
        sed -i "s:# tmpfs:tmpfs:" $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab
        echo "/dev/$ROOT_DISK    /          ext4    defaults,noatime,nodiratime,commit=600,errors=remount-ro       0       1" >> $CWD/$BUILD/$SOURCE/$ROOTFS/etc/fstab || exit 1
    fi
}

setting_debug (){
    message "" "setting" "uart debugging"
    sed 's/#\(ttyS[1-2]\)/\1/' -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/securetty"
    sed 's/#\(s\([1-2]\)\)\(.*\)\(ttyS[0-1]\)\(.*\)\(9600\)/\1\3ttyS\2 115200/' \
        -i "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/inittab"
}

setting_motd (){
    message "" "setting" "motd"

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

setting_rc_local (){
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

setting_wifi (){
    message "" "setting" "wifi"
cat <<EOF >"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.wifi"
#!/bin/sh

wifi_start() {
    if [ -e /sys/class/rkwifi/power ] ; then
        echo "Enable wifi"
        echo 1 > /sys/class/rkwifi/power
        sleep 2
        echo 1 > /sys/class/rkwifi/driver
        /etc/rc.d/rc.inet1 wlan0_start
    else
        echo "No wifi driver"
    fi
}

wifi_stop() {
    if [ -e /sys/class/rkwifi/power ] ; then
        echo "Disable wifi"
        /etc/rc.d/rc.inet1 wlan0_stop
        echo 0 > /sys/class/rkwifi/driver
        sleep 2
        echo 0 > /sys/class/rkwifi/power
    else
        echo "No wifi driver"
    fi

}

case "\$1" in
    'start')
    wifi_start
    ;;
    'stop')
    wifi_stop
    ;;
    *)
    echo "Usage: \$0 {start|stop}"
esac
EOF
#   chmod 755 "$CWD/$BUILD/$SOURCE/${ROOTFS}-$BOARD_NAME-build-$VERSION/etc/rc.d/rc.wifi"


    # fix wifi driver
    sed -i "s#wext#nl80211#" $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.inet1.conf

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local | grep wifi) ]];then
    # add start wifi boot
    cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local"

if [ -x /etc/rc.d/rc.wifi ] ; then
  . /etc/rc.d/rc.wifi \$command
fi
EOF
    fi
}

setting_firstboot (){
    if [[ ! -x $CWD/$BUILD/$SOURCE/$ROOTFS/firstboot ]];then
    message "" "setting" "firstboot"
    # add start wifi boot
    cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/firstboot"
#!/bin/sh

case "\$1" in
  'start')
    if [ -e /firstboot ]; then
        if [ ! -f /swap ]; then
        echo -e "\e[0;37mResizing partition SD card\x1B[0m"
        device="/dev/"\$(lsblk -idn -o NAME | grep mmc)
        (( echo d; echo p; echo n; echo p; echo 1; echo; echo; echo w; ) | fdisk \$device )>/dev/null 2>&1
        #PARTITIONS=\$((\$(fdisk -l \$device | grep \$device | wc -l)-1))
        #((echo d; echo n; echo p; echo \$PARTITIONS; echo; echo; echo w;) | fdisk \$device)>/dev/null
        #((echo d; echo \$PARTITIONS; echo n; echo p; echo ; echo ; echo ; echo w;) | fdisk \$device)>/dev/null
  
        # change root password
                usermod -p  '$(openssl passwd -1 password)' root

        echo -e "\e[0;37mCreating 128Mb emergency swap area\x1B[0m"
        dd if=/dev/zero of=/swap bs=1024 count=131072 status=noxfer >/dev/null 2>&1
        chown root:root /swap
        chmod 0600 /swap
        mkswap /swap >/dev/null 2>&1
        swapon /swap >/dev/null 2>&1
        echo "/swap none swap sw 0 0" >> /etc/fstab
        echo 'vm.swappiness=0' >> /etc/sysctl.conf

        sleep 2
        shutdown -r now
        fi

        echo -e "\e[0;37mResizing SD card file-system\x1B[0m"
        /sbin/resize2fs -p /dev/$ROOT_DISK >/dev/null

        rm -f /firstboot 2>&1>/dev/null
    fi
    ;;
   'stop')
    echo -e "\e[0;37mResizing in next start\x1B[0m"
        ;;
   *)
        echo "Usage: \$0 {start|stop}" >&2
        exit 1
    ;;
esac

EOF
    fi
    chmod 755 "$CWD/$BUILD/$SOURCE/$ROOTFS/firstboot"

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local | grep firstboot) ]];then
    cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/rc.d/rc.local"

if [ -x /firstboot ]; then
  . /firstboot \$command
fi
EOF
    fi
}

setting_dhcpcd (){
    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/dhcpcd.conf | grep nolink) ]];then
        message "" "setting" "dhcpcd.conf"
    cat <<EOF >>"$CWD/$BUILD/$SOURCE/$ROOTFS/etc/dhcpcd.conf"
noarp
nolink

EOF
    fi
}

create_img (){
    if [ "$1" = "xfce" ]; then
        IMAGE="$ROOTFS_XFCE"
    else
        IMAGE="$ROOTFS"
    fi
    # +400M for create swap firstrun
    ROOTFS_SIZE=$(expr $(du -sH $CWD/$BUILD/$SOURCE/$IMAGE | awk '{print $1}') / 1024 + 400)"M"

    message "" "create" "image size $ROOTFS_SIZE"

    if [ "$BOARD_NAME" == "firefly" ];then
        $CWD/$BUILD/$OUTPUT/$TOOLS/mkrootfs $CWD/$BUILD/$SOURCE/$IMAGE ${ROOTFS_SIZE} >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    elif [ "$BOARD_NAME" == "cubietruck" ]; then

        dd if=/dev/zero of=$CWD/$BUILD/$SOURCE/$IMAGE.img bs=1 count=0 seek=$ROOTFS_SIZE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

        LOOP=$(losetup -f)

        losetup $LOOP $CWD/$BUILD/$SOURCE/$IMAGE.img || exit 1

        message "" "save" "$BOOT_LOADER"
        dd if="$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" of=$LOOP bs=1024 seek=8 status=noxfer >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

        message "" "create" "partition"
#       ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >/dev/null 2>&1
#       ( ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >/dev/null 2>&1 ) || true
#       ( ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1 ) # || true
#        ((echo o; echo p; echo n; echo p; echo 1; echo 2048; echo; echo w) | fdisk $LOOP) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || true
        echo -e "\no\nn\np\n1\n2048\n\nw" | fdisk $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || true

        partprobe $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

        losetup -d $LOOP

        # device is busy
        sleep 2

        # 2048 (start) x 512 (block size) = where to mount partition
        losetup -o 1048576 $LOOP $CWD/$BUILD/$SOURCE/$IMAGE.img >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

        message "" "create" "filesystem"
        mkfs.ext4 -F -m 0 -L linuxroot $LOOP >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

        message "" "create" "mount point and mount image"
        mkdir -p $CWD/$BUILD/$SOURCE/image
        mount $LOOP $CWD/$BUILD/$SOURCE/image
        cp -a $CWD/$BUILD/$SOURCE/$IMAGE/* $CWD/$BUILD/$SOURCE/image
        umount $CWD/$BUILD/$SOURCE/image
        rm -rf $CWD/$BUILD/$SOURCE/image
        losetup -d $LOOP
    fi

    if [ -f $CWD/$BUILD/$SOURCE/$IMAGE.img ];then
        mv $CWD/$BUILD/$SOURCE/$IMAGE.img $CWD/$BUILD/$OUTPUT/$FLASH
    fi

    message "" "done" "image $IMAGE"
}

setting_settings (){
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

download_pkg (){
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
                    PKG_NAME=$(wget -q -O - ${_URL_DISTR}/${category} | grep -oP "(\>$(echo $_pkg | sed "s#\+#\\\+#")-[\.\-\+\d\w]+.txz\<)" | sed "s#[><]##g" | head -n1)
                    message "" "download" "package $category/$PKG_NAME"
                    wget -c -nc -nd -np ${_URL_DISTR}/${category}/$PKG_NAME -P $CWD/$BUILD/$PKG/${category}/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
                done
            fi
        fi
    done
    # clean
    count=''
    category=''
    _URL_DISTR=''
}

install_pkg (){
    if [ ! -d "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE" ]; then
    _ROOTFS="$ROOTFS"
    else
    _ROOTFS="$ROOTFS_XFCE"
    fi

#    for category in "$@";do
#    for pkg in $(eval echo \$${category}) ;do
#        message "" "install" "package $category/$pkg"
#        installpkg --root $CWD/$BUILD/$SOURCE/$_ROOTFS $CWD/$BUILD/$PKG/$category/$pkg* >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
#    done
#    done

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
                    installpkg --root $CWD/$BUILD/$SOURCE/$_ROOTFS $CWD/$BUILD/$PKG/$category/${_pkg}* >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
                done
            fi
        fi
    done
    # clean
    count=''
    category=''
    packages=''
}

setting_default_theme_xfce (){
    if [[ ! -d "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/skel/.config/xfce4" ]];then
        message "" "setting" "default settings xfce"
		rsync -a "$CWD/config/xfce/" "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/skel/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
		rsync -a "$CWD/config/xfce/" "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/root/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    fi
}

setting_default_start_x (){
    sed "s#id:3#id:4#" -i $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/inittab
    # fix default xfce
    ln -sf $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/X11/xinit/xinitrc.xfce \
       -r $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/etc/X11/xinit/xinitrc

    if [ "$BOARD_NAME" == "firefly" ]; then
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

	# adjustment for vdpau
    sed -i 's#sunxi_ve_mem_reserve=0#sunxi_ve_mem_reserve=128#' "$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.cmd"
	$CWD/$BUILD/$SOURCE/$BOOT_LOADER/tools/mkimage -C none -A arm -T script -d $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.cmd \
	"$CWD/$BUILD/$SOURCE/$ROOTFS_XFCE/boot/boot.scr" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
}

build_video_driver_pkg (){
    message "" "create" "pakage $VIDEO_DRIVER"

    mkdir -p $CWD/$BUILD/$PKG/$VIDEO_DRIVER/etc/{X11,rc.d,udev/rules.d} $CWD/$BUILD/$PKG/$VIDEO_DRIVER/usr/lib
    tar --strip-components=1 -xzf $CWD/$BUILD/$SOURCE/$VIDEO_DRIVER.tar.gz -C $CWD/$BUILD/$PKG/$VIDEO_DRIVER/usr/lib
    find $CWD/$BUILD/$PKG/$VIDEO_DRIVER/usr/lib -exec chmod 755 {} \; -exec chown root:root {} \;

    cat <<EOF >$CWD/$BUILD/$PKG/$VIDEO_DRIVER/etc/X11/xorg.conf

Section "Device"
    Identifier  "Mali FBDEV"
#   Driver      "armsoc"
    Driver      "fbdev"
    Option      "fbdev"         "/dev/fb0"
    Option      "Fimg2DExa"     "false"
    Option      "DRI2"          "true"
    Option      "DRI2_PAGE_FLIP"    "false"
    Option      "DRI2_WAIT_VSYNC"   "true"
#   Option      "Fimg2DExaSolid"    "false"
#   Option      "Fimg2DExaCopy"     "false"
#   Option      "Fimg2DExaComposite"    "false"
#        Option          "SWcursorLCD"           "false"
#   Option      "Debug"         "true"
EndSection


Section "ServerFlags"
    Option     "NoTrapSignals" "true"
    Option     "DontZap" "false"

    # Disable DPMS timeouts.
#    Option     "StandbyTime" "0"
#    Option     "SuspendTime" "0"
#    Option     "OffTime" "0"

    # Disable screen saver timeout.
#    Option     "BlankTime" "0"
EndSection

Section "Monitor"
    Identifier "DefaultMonitor"
EndSection

Section "Device"
    Identifier "DefaultDevice"
#    Option     "monitor-LVDS1" "DefaultMonitor"
EndSection
Section "Screen"
    Identifier  "DefaultScreen"
    Device      "Mali FBDEV"
    DefaultDepth    24

EndSection

Section "ServerLayout"
    Identifier "DefaultLayout"
    Screen     "DefaultScreen"
EndSection
EOF

    cat <<EOF >$CWD/$BUILD/$PKG/$VIDEO_DRIVER/etc/rc.d/rc.fbset
#!/bin/bash

if [ -x /usr/sbin/fbset ];then
    /usr/sbin/fbset -a -nonstd 1 -depth 32 -rgba "8/0,8/8,8/16,8/24"
fi
EOF

    chmod 755 $CWD/$BUILD/$PKG/$VIDEO_DRIVER/etc/rc.d/rc.fbset

# fix permission
    cat <<EOF >$CWD/$BUILD/$PKG/$VIDEO_DRIVER/etc/udev/rules.d/50-mali.rules
KERNEL=="fb*", MODE="0660", GROUP="video"
KERNEL=="mali*", MODE="0660", GROUP="video"
EOF

    cd $CWD/$BUILD/$PKG/$VIDEO_DRIVER
    makepkg  -l n -c n $CWD/$BUILD/$PKG/$VIDEO_DRIVER-${_ARCH}-${_BUILD}${_PACKAGER}.txz
}

install_video_driver_pkg (){
    message "" "install" "$VIDEO_DRIVER"
    installpkg --root $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE $CWD/$BUILD/$PKG/$VIDEO_DRIVER-* >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
}

setting_move_to_nand (){
    message "" "setting" "data move to nand"
    install -m755 -D "$CWD/bin/$BOARD_NAME/setup.sh" "$CWD/$BUILD/$SOURCE/$ROOTFS/root/setup.sh"

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/etc/issue | grep setup.sh) ]];then
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

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/root/.bashrc | grep setup.sh) ]];then
        cat <<EOF >$CWD/$BUILD/$SOURCE/$ROOTFS/root/.bashrc
alias setup='/root/setup.sh'
EOF
    fi

    if [[ ! $(cat $CWD/$BUILD/$SOURCE/$ROOTFS/root/.bash_profile | grep .bashrc) ]];then
        cat <<EOF >$CWD/$BUILD/$SOURCE/$ROOTFS/root/.bash_profile
source ~/.bashrc
EOF
    fi
}

setting_first_login (){
    message "" "setting" "first login"
    install -m755 -D "$CWD/bin/check_first_login.sh" "$CWD/$BUILD/$SOURCE/$ROOTFS/etc/profile.d/check_first_login.sh"
    touch "$CWD/$BUILD/$SOURCE/$ROOTFS/root/.never_logged"
}
