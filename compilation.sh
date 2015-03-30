#!/bin/bash



#---------------------------------------------
# create dir
#---------------------------------------------
download (){
	echo "------ Download $LINUX_UPGRADE_TOOL"
	wget -c --no-check-certificate $URL_LINUX_UPGRADE_TOOL/$LINUX_UPGRADE_TOOL.zip -O $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL.zip || exit 1
	unzip -o $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL.zip -d $CWD/$BUILD/$SOURCE/ || exit 1

	echo "------ Download $URL_XTOOLS_OLD"
	if [ -d $CWD/$BUILD/$SOURCE/$XTOOLS_OLD ]; then
	    cd $CWD/$BUILD/$SOURCE/$XTOOLS_OLD && git pull origin HEAD && cd $CWD
	else
	    git clone $URL_XTOOLS_OLD $CWD/$BUILD/$SOURCE/$XTOOLS_OLD || exit 1
	fi

	echo "------ Download $XTOOLS"
	wget -c --no-check-certificate $URL_XTOOLS -O $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz || exit 1
	tar xvf $CWD/$BUILD/$SOURCE/$XTOOLS.tar.?z* -C $CWD/$BUILD/$SOURCE/ || exit 1

	echo "------ Download $RK2918_TOOLS"
	if [ -d $CWD/$BUILD/$SOURCE/$RK2918_TOOLS ]; then
	    cd $CWD/$BUILD/$SOURCE/$RK2918_TOOLS && git pull origin HEAD && cd $CWD
	else
	    git clone $URL_RK2918_TOOLS/$RK2918_TOOLS $CWD/$BUILD/$SOURCE/$RK2918_TOOLS || exit 1
	fi

	echo "------ Download $RKFLASH_TOOLS"
	if [ -d $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS ]; then
	    cd $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS && git pull origin HEAD && cd $CWD
	else
	    git clone $URL_RKFLASH_TOOLS/$RKFLASH_TOOLS $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS || exit 1
	fi
	
	echo "------ Download $MKBOOTIMG_TOOLS"
	if [ -d $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS ]; then
	    cd $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS && git pull origin HEAD && cd $CWD
	else
	    git clone $URL_MKBOOTIMG_TOOLS/$MKBOOTIMG_TOOLS $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS || exit 1
	fi

	echo "------ Download $BOOT_LOADER"
	if [ -d $CWD/$BUILD/$SOURCE/$BOOT_LOADER ]; then
	    cd $CWD/$BUILD/$SOURCE/$BOOT_LOADER && git pull origin HEAD && cd $CWD
	else
	    git clone $URL_BOOT_LOADER_SOURCE/$BOOT_LOADER $CWD/$BUILD/$SOURCE/$BOOT_LOADER || exit 1
	fi

	echo "------ Download $LINUX_SOURCE"
	if [ -d $CWD/$BUILD/$SOURCE/$LINUX_SOURCE ]; then
	    cd $CWD/$BUILD/$SOURCE/$LINUX_SOURCE && git pull origin HEAD && cd $CWD
	else
	    git clone $URL_LINUX_SOURCE/$LINUX_SOURCE $CWD/$BUILD/$SOURCE/$LINUX_SOURCE || exit 1
	fi

        if [ ! -f $CWD/$BUILD/$SOURCE/$FIRMWARE ]; then
            echo "------ Download $FIRMWARE"
            wget -c --no-check-certificate $URL_FIRMWARE/$FIRMWARE -O $CWD/$BUILD/$SOURCE/$FIRMWARE || exit 1
        fi
}

kernel_version (){
	local VER
	VER=$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
	EXTRAVERSION=$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
	if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
	echo "------ Get kernel version $VER"
	eval "$1=\$VER"
}

compile_rk2918 (){
	echo "------ Compiling $RK2918_TOOLS"
	PROGRAMS="afptool img_unpack img_maker mkkrnlimg"
	cd $CWD/$BUILD/$SOURCE/$RK2918_TOOLS
	make $CTHREADS || exit 1

	for p in $PROGRAMS;do
		echo "copy program: $p"
		mv $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
	done
}

compile_rkflashtool (){
	echo "------ Compiling $RKFLASH_TOOLS"
	PROGRAMS="rkcrc rkflashtool rkmisc rkpad rkparameters rkparametersblock rkunpack rkunsign"
	cd $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS
	make clean || exit 1
	make $CTHREADS || exit 1

	for p in $PROGRAMS;do
		echo "copy program: $p"
		cp $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
	done
}

compile_mkbooting (){
	echo "------ Compiling $MKBOOTIMG_TOOLS"
	PROGRAMS="afptool img_maker mkbootimg unmkbootimg mkrootfs mkupdate mkcpiogz unmkcpiogz"
	cd $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS
	make clean || exit 1
	make $CTHREADS || exit 1

	for p in $PROGRAMS;do
		echo "copy program: $p"
		cp $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
	done
}

compile_boot_loader (){
	echo "------ Compiling $BOOT_LOADER"
	cd $CWD/$BUILD/$SOURCE/$BOOT_LOADER
	make ARCH=arm CROSS_COMPILE=$CROSS_OLD clean || exit 1
	make ARCH=arm $BOOT_LOADER_CONFIG CROSS_COMPILE=$CROSS_OLD || exit 1
	make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS_OLD || exit 1
	find -name "RK3288UbootLoader*" -exec install -D {} $CWD/$BUILD/$OUTPUT/$FLASH/{} \;
}

compile_kernel (){
	if [ -d "$CWD/$BUILD/$SOURCE/$LINUX_SOURCE" ]; then
		echo "------ Compiling kernel"
		cd $CWD/$BUILD/$SOURCE/$LINUX_SOURCE

		# fix firmware /system /lib
		sed -i "s#\"/system/etc/firmware/\"#\"/lib/firmware/\"#" drivers/net/wireless/rockchip_wlan/rkwifi/rk_wifi_config.c

		# fix kernel version
		sed -i "/SUBLEVEL = 0/d" Makefile

		# delete previous creations
		make CROSS_COMPILE=$CROSS clean || exit 1

		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS firefly-rk3288-linux_defconfig || exit 1

#		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS menuconfig  || exit 1

		# this way of compilation is much faster. We can use multi threading here but not later
		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS zImage modules || exit 1
		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS firefly-rk3288.dtb || exit 1
	
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules modules_install || exit 1
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules firmware_install || exit 1
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$CWD/$BUILD/$PKG/kernel-headers/usr headers_install || exit 1
	else
		echo "ERROR: Source file $1 does not exists. Check fetch_from_github configuration."
		exit
	fi
	sync
}

build_pkg (){
	kernel_version _VERSION
	_ARCH="arm"
	_BUILD=1
	_PACKAGER="mara"

	echo "------ Create kernel pakages"
	# split install_modules -> firmware
	install -dm755 "$CWD/$BUILD/$PKG/kernel-firmware/lib"
	if [ -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware ];then
		mv $CWD/$BUILD/$PKG/kernel-modules/lib/firmware "$CWD/$BUILD/$PKG/kernel-firmware/lib"
		# clean-up unnecessary files generated during install
		find "$CWD/$BUILD/$PKG/kernel-firmware/lib" \( -name .install -o -name ..install.cmd \) -delete
	fi
	
	# add firmware
	unzip -o $CWD/$BUILD/$SOURCE/$FIRMWARE -d $CWD/$BUILD/$SOURCE/ || exit 1
	cp -a $CWD/$BUILD/$SOURCE/overlay-master/overlay-rksdk/files-overlay-rk3288/system/etc/firmware $CWD/$BUILD/$PKG/kernel-firmware/lib/


	cd $CWD/$BUILD/$PKG/kernel-modules/

	install -dm755 "$CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/"
	echo -e "#!/bin/sh\n" > $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules
	for mod in $MODULES;do
		echo "/sbin/modprobe $mod" >> $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules
	done
	chmod 755 $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules
	cd $CWD/$BUILD/$PKG/kernel-modules/lib/modules/$VERSION*
	rm build source
	ln -s /usr/include build
	ln -s /usr/include source
        cd $CWD/$BUILD/$PKG/kernel-modules/
        makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-modules-${_VERSION}-${_ARCH}-${_BUILD}${_PACKAGER}.txz
	
	cd $CWD/$BUILD/$PKG/kernel-headers/
	makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-headers-${_VERSION}-${_ARCH}-${_BUILD}${_PACKAGER}.txz
	
	cd $CWD/$BUILD/$PKG/kernel-firmware/
	makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-firmware-${_VERSION}-${_ARCH}-${_BUILD}${_PACKAGER}.txz
}

add_linux_upgrade_tool (){
	echo "------ Add $LINUX_UPGRADE_TOOL"
	# add tool for flash boot loader
	cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/upgrade_tool $CWD/$BUILD/$OUTPUT/$TOOLS/
	cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/config.ini $CWD/$BUILD/$OUTPUT/$TOOLS/
}

build_parameters (){
	echo "------ Create parameters"
	# add parameters for flash
	cat <<EOF >"$CWD/$BUILD/$OUTPUT/$FLASH/parameters.txt"
FIRMWARE_VER:4.4.2
MACHINE_MODEL:rk30sdk
MACHINE_ID:007
MANUFACTURER:RK30SDK
MAGIC: 0x5041524B
ATAG: 0x60000800
MACHINE: 3066
CHECK_MASK: 0x80
PWR_HLD: 0,0,A,0,1
#KERNEL_IMG: 0x62008000
#FDT_NAME: rk-kernel.dtb
#RECOVER_KEY: 1,1,0,20,0
CMDLINE:console=tty0 console=tty0 earlyprintk root=/dev/$ROOT_DISK rw rootfstype=ext4 init=/sbin/init initrd=0x62000000,0x00800000 mtdparts=rk29xxnand:0x00008000@0x00002000(resource),0x00008000@0x0000A000(boot),-@0x00012000(linuxroot)
EOF
}

build_resource (){
	echo "------ Create resource"
	# create resource for flash
	cd $CWD/$BUILD/$OUTPUT/$FLASH
	$CWD/$BUILD/$SOURCE/$LINUX_SOURCE/resource_tool $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/logo.bmp $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/dts/firefly-rk3288.dtb || exit 1
}

build_boot (){
	echo "------ Create boot"
	# create boot for flash
	cd $CWD/$BUILD/$SOURCE
	$CWD/$BUILD/$OUTPUT/$TOOLS/mkcpiogz $CWD/initrd-tree || exit 1
	mv -f $CWD/initrd-tree.cpio.gz . || exit 1
	$CWD/$BUILD/$OUTPUT/$TOOLS/mkbootimg --kernel $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/zImage --ramdisk $CWD/$BUILD/$SOURCE/initrd-tree.cpio.gz -o $CWD/$BUILD/$OUTPUT/$FLASH/boot.img || exit 1
	if [ -e $CWD/$BUILD/$SOURCE/initrd-tree.cpio.gz ];then
		rm $CWD/$BUILD/$SOURCE/initrd-tree.cpio.gz
	fi
}


build_flash_script (){
	echo "------ Create flash script"
	cat <<EOF >"$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh"
#!/bin/sh

if [ "$EUID" -ne 0 ];then
	echo "Please run as root"
	exit
fi

echo "------ flash boot loader"
$CWD/$BUILD/$OUTPUT/$TOOLS/upgrade_tool ul \$(ls | grep RK3288UbootLoader) || exit 1
echo "------ flash parameters"
$CWD/$BUILD/$OUTPUT/$TOOLS/rkflashtool P < parameters.txt || exit 1
echo "------ flash resource"
$CWD/$BUILD/$OUTPUT/$TOOLS/rkflashtool w resource < resource.img || exit 1
echo "------ flash boot"
$CWD/$BUILD/$OUTPUT/$TOOLS/rkflashtool w boot < boot.img || exit 1
echo "------ flash rootfs"
$CWD/$BUILD/$OUTPUT/$TOOLS/rkflashtool w linuxroot < ${ROOTFS}_${VERSION}.img || exit 1
echo "------ reboot device"
$CWD/$BUILD/$OUTPUT/$TOOLS/rkflashtool b RK320A || exit 1
EOF
chmod 755 "$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh"
}

#download
#compile_rk2918
#compile_rkflashtool
#compile_mkbooting
#compile_boot_loader
#compile_kernel
build_pkg
add_linux_upgrade_tool
build_parameters
build_resource
build_boot
build_flash_script


