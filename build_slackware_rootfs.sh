#!/bin/bash



if [ empty $CWD ];then
    exit
fi

clean_rootfs (){
	echo "------ Clean ${ROOTFS}-build-$VERSION"
	rm -rf $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION || exit 1
	mkdir -p $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION || exit 1
}

download_rootfs (){
        echo "------ Download ${ROOTFS}"
	wget -c --no-check-certificate $URL_ROOTFS/${ROOTFS}.tar.xz -O $CWD/$BUILD/$SOURCE/${ROOTFS}.tar.xz || exit 1
}

prepare (){
	echo "------ Prepare ${ROOTFS}"
	tar xvf $CWD/$BUILD/$SOURCE/${ROOTFS}.tar.?z* -C $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION || exit 1
	installpkg --root $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION $CWD/$BUILD/$PKG/kernel-*.txz || exit 1
}

setting_fstab (){
	echo "------ Settings fstab ${ROOTFS}-build-$VERSION"
	echo "/dev/$ROOT_DISK      /               ext4    defaults       0       1" >> $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/fstab || exit 1
}

setting_motd (){
	echo "------ Settings motd ${ROOTFS}-build-$VERSION"
	cat <<EOF >"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/motd"
 ____  ____  ____  ____  ____  __   _  _    ____  _  _  ___  ___   ___  ___
( ___)(_  _)(  _ \( ___)( ___)(  ) ( \/ )  (  _ \( )/ )(__ )(__ \ ( _ )( _ ) 
 )__)  _)(_  )   / )__)  )__)  )(__ \  /    )   / )  (  (_ \ / _/ / _ \/ _ \ 
(__)  (____)(_)\_)(____)(__)  (____)(__)   (_)\_)(_)\_)(___/(____)\___/\___/ 
Slackware
EOF
}

setting_wifi (){
	echo "------ Settings wifi ${ROOTFS}-build-$VERSION"
cat <<EOF >"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.wifi"
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
	    echo "Enable wifi"
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
#	chmod 755 "$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.wifi"


	# fix wifi driver
	sed -i "s#wext#nl80211#" $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.inet1.conf

	# add start wifi boot
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.local"
if [ -x /etc/rc.d/rc.wifi ] ; then
    /etc/rc.d/rc.wifi start
fi
EOF
}

setting_firstboot (){
	echo "------ Settings firstboot ${ROOTFS}-build-$VERSION"
	# add start wifi boot
	touch "$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/firstboot"
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.local"
if [ -e /firstboot ]; then
    resize2fs -p /dev/$ROOT_DISK
    rm -f /firstboot 2>/dev/null
fi
EOF
}

create_img (){
	$CWD/$BUILD/$OUTPUT/$TOOLS/mkrootfs $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION $ROOTFS_SIZE
	if [ -e $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION.img ];then
		mv $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION.img $CWD/$BUILD/$OUTPUT/$FLASH
	fi
}


clean_rootfs
download_rootfs
prepare
setting_fstab
setting_motd
setting_wifi
setting_firstboot
create_img
exit





cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/wpa_supplicant.conf"
#eapol_version=2
#update_config=1

network={
    ssid="{###}"
    psk="qwerty0000qwerty1111"
    proto=RSN
    key_mgmt=WPA-PSK
    pairwise=CCMP TKIP
    auth_alg=OPEN
}
EOF





