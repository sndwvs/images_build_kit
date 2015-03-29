#!/bin/bash

set -e

CWD=$(pwd)

URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
ROOTFS="slack-current-miniroot"
VERSION="09Mar15"
SIZE="512M"
ROOT_DISK="mmcblk0p3"

SOURCE="source"
PKG="pkg"
OUTPUT="output"
TOOLS="tools"
FLASH="flash"

clean_rootfs (){
	cd $CWD
	echo "------ Clean ${ROOTFS}_${VERSION}"
	rm -rf $SOURCE/${ROOTFS}_${VERSION} || exit 1
	mkdir -p $SOURCE/${ROOTFS}_${VERSION} || exit 1
}

download (){
	cd $CWD
        echo "------ Download ${ROOTFS}_${VERSION}"
	wget -c --no-check-certificate $URL_ROOTFS/${ROOTFS}_${VERSION}.tar.xz -O $SOURCE/${ROOTFS}_${VERSION}.tar.xz || exit 1
}

prepare (){
	cd $CWD
	echo "------ Prepare ${ROOTFS}_${VERSION}"
	tar xvf $SOURCE/${ROOTFS}_${VERSION}.tar.xz -C $SOURCE/${ROOTFS}_${VERSION} || exit 1
	installpkg --root $SOURCE/${ROOTFS}_${VERSION} $PKG/kernel-*.txz || exit 1
}

setting_fstab (){
	cd $CWD
	echo "------ Settings fstab ${ROOTFS}_${VERSION}"
	echo "/dev/$ROOT_DISK      /               ext4    defaults 0       1" >> $SOURCE/${ROOTFS}_${VERSION}/etc/fstab || exit 1
}

setting_wifi (){
	cd $CWD
	echo "------ Settings wifi ${ROOTFS}_${VERSION}"
cat <<EOF >"$SOURCE/${ROOTFS}_${VERSION}/etc/rc.d/rc.wifi"
#!/bin/sh

wifi_start() {
	if [ -e /sys/class/rkwifi/power ] ; then
	    echo "Enable wifi"
	    echo 1 > /sys/class/rkwifi/power
	    sleep 2
	    echo 1 > /sys/class/rkwifi/driver
	    /etc/rc.d/rc.inet1 restart
	else
	    echo "No wifi driver"
	fi
}

wifi_stop() {
	if [ -e /sys/class/rkwifi/power ] ; then
	    echo "Enable wifi"
	    echo 0 > /sys/class/rkwifi/driver
	    sleep 2
	    echo 0 > /sys/class/rkwifi/power
	    /etc/rc.d/rc.inet1 stop
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
	chmod 755 "$SOURCE/${ROOTFS}_${VERSION}/etc/rc.d/rc.wifi"


	# fix wifi driver
	sed -i "s#wext#nl80211#" $SOURCE/${ROOTFS}_${VERSION}/etc/rc.d/rc.inet1.conf

	# add start wifi boot
	cat <<EOF >>"$SOURCE/${ROOTFS}_${VERSION}/etc/rc.d/rc.local"
if [ -x /etc/rc.d/rc.wifi ] ; then
    /etc/rc.d/rc.wifi start
fi
EOF
}

setting_firstboot (){
	cd $CWD
	echo "------ Settings firstboot ${ROOTFS}_${VERSION}"
	# add start wifi boot
	touch "$SOURCE/${ROOTFS}_${VERSION}/firstboot"
	cat <<EOF >>"$SOURCE/${ROOTFS}_${VERSION}/etc/rc.d/rc.local"
if [ -e /firstboot ]; then
    resize2fs -p /dev/$ROOT_DISK
    rm -f /firstboot 2>/dev/null
fi
EOF
}

create_img (){
	$OUTPUT/$TOOLS/mkrootfs $SOURCE/${ROOTFS}_${VERSION} $SIZE
	if [ -e $SOURCE/${ROOTFS}_${VERSION}.img ];then
		mv $SOURCE/${ROOTFS}_${VERSION}.img $OUTPUT/$FLASH
	fi
}


clean_rootfs
download
prepare
setting_fstab
setting_wifi
setting_firstboot
create_img
exit





cat <<EOF >>"$SOURCE/${ROOTFS}_${VERSION}/etc/wpa_supplicant.conf"
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




