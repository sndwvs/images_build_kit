#!/bin/bash



if [ -z $CWD ];then
    exit
fi

clean_rootfs (){
	if [ -d $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION ];then
	    echo "------ Clean ${ROOTFS}-build-$VERSION"
	    rm -rf $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION || exit 1
	    if [ -d $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-$VERSION ];then
		rm -rf $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION} || exit 1
	    fi
	fi
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
	if [[ ! $(cat $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/fstab | grep $ROOT_DISK) ]];then
	    echo "------ Settings fstab ${ROOTFS}-build-$VERSION"
	    echo "/dev/$ROOT_DISK      /               ext4    defaults       0       1" >> $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/fstab || exit 1
	fi
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
#	chmod 755 "$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.wifi"


	# fix wifi driver
	sed -i "s#wext#nl80211#" $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.inet1.conf

	if [[ ! $(cat $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.local | grep wifi) ]];then
	# add start wifi boot
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.local"
if [ -x /etc/rc.d/rc.wifi ] ; then
    /etc/rc.d/rc.wifi start
fi
EOF
	fi
}

setting_firstboot (){
	if [[ ! -x $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/firstboot ]];then
	echo "------ Settings firstboot ${ROOTFS}-build-$VERSION"
	# add start wifi boot
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/firstboot"
#!/bin/sh

if [ -e /firstboot ]; then
    resize2fs -p /dev/$ROOT_DISK
    # add user
    echo user | adduser 2>&1>/dev/null
    echo "user:password" | chpasswd 1>&2>/dev/null

    rm -f /firstboot 2>&1>/dev/null
fi

EOF
	fi
	chmod 755 "$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/firstboot"

	if [[ ! $(cat $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.local | grep firstboot) ]];then
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/rc.d/rc.local"
if [ -x /firstboot ]; then
    /firstboot 2>&1>/dev/null
fi
EOF
	fi
}

setting_dhcpcd (){
	if [[ ! $(cat $CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/dhcpcd.conf | grep nolink) ]];then
		echo "------ Settings dhcpcd.conf ${ROOTFS}-build-$VERSION"
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS}-build-$VERSION/etc/dhcpcd.conf"
noarp
nolink

EOF
	fi
}

create_img (){
	if [ "$1" = "xfce" ]; then
	    IMAGE="${ROOTFS_XFCE}-build-${VERSION}"
	else
	    IMAGE="${ROOTFS}-build-${VERSION}"
	fi
	ROOTFS_SIZE=$(expr $(du -sH $CWD/$BUILD/$SOURCE/$IMAGE | awk '{print $1}') / 1024 + 200)"M"

	$CWD/$BUILD/$OUTPUT/$TOOLS/mkrootfs $CWD/$BUILD/$SOURCE/$IMAGE ${ROOTFS_SIZE} || exit 1
	if [ -f $CWD/$BUILD/$SOURCE/$IMAGE.img ];then
	    mv $CWD/$BUILD/$SOURCE/$IMAGE.img $CWD/$BUILD/$OUTPUT/$FLASH
	fi
}

download_pkg (){
    for category in $CATEGORY_PKG;do
	wget -c -q -nc -nd -np -r -A txz,tgz $URL_DISTR/$category/ -P $CWD/$BUILD/$PKG/$category/
    done
}

install_pkg (){
    for category in $CATEGORY_PKG;do
	for pkg in $(eval echo \$${category}) ;do
	    installpkg --root $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION} $CWD/$BUILD/$PKG/$category/$pkg* || exit 1
	done
    done
}

setting_default_theme_xfce (){
	if [[ ! -d "$CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml" ]];then
	install -m755 -d "$CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita"/>
    <property name="IconThemeName" type="string" value="Tango"/>
    <property name="DoubleClickTime" type="empty"/>
    <property name="DoubleClickDistance" type="empty"/>
    <property name="DndDragThreshold" type="empty"/>
    <property name="CursorBlink" type="empty"/>
    <property name="CursorBlinkTime" type="empty"/>
    <property name="SoundThemeName" type="empty"/>
    <property name="EnableEventSounds" type="empty"/>
    <property name="EnableInputFeedbackSounds" type="empty"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CanChangeAccels" type="empty"/>
    <property name="ColorPalette" type="empty"/>
    <property name="FontName" type="string" value="Sans 10"/>
    <property name="IconSizes" type="empty"/>
    <property name="KeyThemeName" type="empty"/>
    <property name="ToolbarStyle" type="empty"/>
    <property name="ToolbarIconSize" type="empty"/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuBarAccel" type="empty"/>
    <property name="CursorThemeName" type="empty"/>
    <property name="CursorThemeSize" type="empty"/>
    <property name="DecorationLayout" type="empty"/>
  </property>
  <property name="Xft" type="empty">
    <property name="HintStyle" type="string" value="hintfull"/>
  </property>
</channel>
EOF

	install -D "$CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" "$CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
	fi
}

setting_default_start_x (){
	sed "s#id:3#id:4#" -i $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/inittab
	# fix default xfce
	cd $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/X11/xinit || exit 1
	ln -sf xinitrc.xfce xinitrc || exit 1

	if [[ ! $(cat $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/rc.d/rc.local | grep fbset) ]];then
	# add start fbset for DefaultDepth 24
	cat <<EOF >>"$CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION}/etc/rc.d/rc.local"
if [ -x /etc/rc.d/rc.fbset ] ; then
    /etc/rc.d/rc.fbset
fi

EOF
	fi
}

download_video_driver (){
	echo "------ Download $VIDEO_DRIVER"
	wget -c --no-check-certificate $URL_VIDEO_DRIVER/$VIDEO_DRIVER.tar.gz -O $CWD/$BUILD/$SOURCE/$VIDEO_DRIVER.tar.gz || exit 1
}

build_video_driver_pkg (){
	echo "------ Create $VIDEO_DRIVER pakages"

	mkdir -p $CWD/$BUILD/$PKG/$VIDEO_DRIVER/etc/{X11,rc.d,udev/rules.d} $CWD/$BUILD/$PKG/$VIDEO_DRIVER/usr/lib
	tar --strip-components=1 -xzf $CWD/$BUILD/$SOURCE/$VIDEO_DRIVER.tar.gz -C $CWD/$BUILD/$PKG/$VIDEO_DRIVER/usr/lib
	find $CWD/$BUILD/$PKG/$VIDEO_DRIVER/usr/lib -exec chmod 755 {} \; -exec chown root:root {} \;

	cat <<EOF >$CWD/$BUILD/$PKG/$VIDEO_DRIVER/etc/X11/xorg.conf

Section "Device"
	Identifier	"Mali FBDEV"
#	Driver		"armsoc"
	Driver		"fbdev"
	Option		"fbdev"			"/dev/fb0"
	Option		"Fimg2DExa"		"false"
	Option		"DRI2"			"true"
	Option		"DRI2_PAGE_FLIP"	"false"
	Option		"DRI2_WAIT_VSYNC"	"true"
#	Option		"Fimg2DExaSolid"	"false"
#	Option		"Fimg2DExaCopy"		"false"
#	Option		"Fimg2DExaComposite"	"false"
#        Option          "SWcursorLCD"           "false"
#	Option		"Debug"			"true"
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
	Identifier 	"DefaultScreen"
	Device     	"Mali FBDEV"
	DefaultDepth 	24

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
	echo "------ Install $VIDEO_DRIVER"
        installpkg --root $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION} $CWD/$BUILD/$PKG/$VIDEO_DRIVER-* || exit 1
}



