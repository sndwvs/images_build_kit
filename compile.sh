#!/bin/bash

set -e

CWD=$(pwd)

CTHREADS="-j6"

DEST=$CWD

URLXTOOLS="http://archlinuxarm.org/builder/xtools"
XTOOLS="x-tools7h.tar.xz"
URLSUNXITOOLS="https://github.com/linux-sunxi"
SUNXITOOLS="sunxi-tools"
FIRMWARE="ap6210.zip"
FIRMWARE1="linux-firmware.zip"
FIRMWARESOURCE="https://github.com/igorpecovnik/lib/raw/next/bin"
BOOTLOADER="https://github.com/linux-sunxi"
URLLINUXSOURCE="https://github.com/dan-and"
BOOTSOURCE="u-boot-sunxi"
BOOTCONFIG="Cubietruck_config"
LINUXSOURCE="linux-sunxi"
LINUXCONFIG="linux-sunxi.config"
LINUXCONFIGSOURCE="https://github.com/igorpecovnik/lib/raw/next/config"
MODULES="hci_uart gpio_sunxi bt_gpio wifi_gpio rfcomm hidp sunxi-ir bonding spi_sun7i bcmdhd ump mali mali_drm"

SOURCE="source"
PKG="pkg"
OUTPUT="output"


export PATH=$PATH:$CWD/${SOURCE}/arm-unknown-linux-gnueabihf/bin:$CWD/$OUTPUT/$BOOTSOURCE/

rm -rf ${CWD}/{$PKG,$OUTPUT}
mkdir -p ${CWD}/{$SOURCE,$PKG,$OUTPUT}


download (){

	cd $CWD

#	if [ -f $SOURCE/$XTOOLS ];then
#	    echo "------ Remove x-tools"
#	    rm $SOURCE/$XTOOLS
#	fi
	echo "------ Download x-tools"
#	wget -c --no-check-certificate $URLXTOOLS/$XTOOLS -O $SOURCE/$XTOOLS
	tar xfv $SOURCE/$XTOOLS --strip-components=1 -C $SOURCE/

	echo "------ Download $BOOTSOURCE"
	if [ -d $SOURCE/$BOOTSOURCE ];then
	    cd $SOURCE/$BOOTSOURCE && git pull && cd $CWD
	else
	    git clone $BOOTLOADER/$BOOTSOURCE $SOURCE/$BOOTSOURCE
	fi

	echo "------ Download $SUNXITOOLS"
	if [ -d $SOURCE/$SUNXITOOLS ];then
	    cd $SOURCE/$SUNXITOOLS && git pull && cd $CWD
	else
	    git clone $URLSUNXITOOLS/$SUNXITOOLS $SOURCE/$SUNXITOOLS
	fi

	if [ ! -f $SOURCE/$FIRMWARE ]; then
	    echo "------ Download $FIRMWARE"
	    wget --no-check-certificate $FIRMWARESOURCE/$FIRMWARE -O $SOURCE/$FIRMWARE
	fi
	if [ ! -f $SOURCE/$FIRMWARE1 ]; then
	    echo "------ Download $FIRMWARE1"
	    wget --no-check-certificate $FIRMWARESOURCE/$FIRMWARE1 -O $SOURCE/$FIRMWARE1
	fi
	if [ ! -f $SOURCE/$LINUXCONFIG ]; then
	    echo "------ Download $LINUXCONFIG"
	    wget --no-check-certificate $LINUXCONFIGSOURCE/$LINUXCONFIG -O $SOURCE/$LINUXCONFIG
	fi

	echo "------ Download $LINUXSOURCE"
	if [ -d $SOURCE/$LINUXSOURCE ]; then
	    cd $SOURCE/$LINUXSOURCE && git pull origin HEAD && cd $CWD
	else
	    git clone $URLLINUXSOURCE/$LINUXSOURCE $SOURCE/$LINUXSOURCE
	fi

}

kernel_version (){
	local VER
	VER=$(cat $CWD/$SOURCE/$LINUXSOURCE/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$SOURCE/$LINUXSOURCE/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$SOURCE/$LINUXSOURCE/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
	EXTRAVERSION=$(cat $CWD/$SOURCE/$LINUXSOURCE/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
	if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
	echo "------ Get kernel version $VER"
	eval "$1=\$VER"
}

compile_uboot (){
	echo "------ Compiling universal boot loader"
	cd $CWD/$SOURCE/$BOOTSOURCE
	make -s CROSS_COMPILE=arm-unknown-linux-gnueabihf- clean || exit 1

	make $CTHREADS $BOOTCONFIG CROSS_COMPILE=arm-unknown-linux-gnueabihf- || exit 1
	## patch mainline uboot configuration to boot with old kernels
	#echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $DEST/$BOOTSOURCE/.config
	#echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $DEST/$BOOTSOURCE/spl/.config
	#echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y" >> $DEST/$BOOTSOURCE/.config
	#echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y"	>> $DEST/$BOOTSOURCE/spl/.config

	make $CTHREADS CROSS_COMPILE=arm-unknown-linux-gnueabihf- || exit 1

	mkdir -p $CWD/$OUTPUT/$BOOTSOURCE || exit 1
	mv tools/mkimage $CWD/$OUTPUT/$BOOTSOURCE/ || exit 1
}

compile_sunxi_tools (){
	echo "------ Compiling sunxi tools"
	cd $CWD/$SOURCE/$SUNXITOOLS
	# for host
	make -s clean && make -s fex2bin && make -s bin2fex || exit 1
#	cp fex2bin bin2fex /usr/local/bin/
	# for destination
	make -s clean && make $CTHREADS 'fex2bin' CC=arm-unknown-linux-gnueabihf-gcc || exit 1
	make $CTHREADS 'bin2fex' CC=arm-unknown-linux-gnueabihf-gcc && make $CTHREADS 'nand-part' CC=arm-unknown-linux-gnueabihf-gcc || exit 1
}


compile_kernel (){
	if [ -d "$CWD/$SOURCE/$LINUXSOURCE" ]; then
		echo "------ Compiling kernel"
		cd $CWD/$SOURCE/$LINUXSOURCE

		# Attempting to run 'firmware_install' with CONFIG_USB_SERIAL_TI=y when
		# using make 3.82 results in an error
		# make[2]: *** No rule to make target `/lib/firmware/./', needed by
		# `/lib/firmware/ti_3410.fw'.  Stop.
		if [[ `grep '$(INSTALL_FW_PATH)/$$(dir %)' scripts/Makefile.fwinst` ]];then
		    sed -i 's:$(INSTALL_FW_PATH)/$$(dir %):$$(dir $(INSTALL_FW_PATH)/%):' scripts/Makefile.fwinst
		fi

		# delete previous creations
		make CROSS_COMPILE=arm-unknown-linux-gnueabihf- clean  || exit 1

		# adding custom firmware to kernel source
		unzip -o $CWD/$SOURCE/$FIRMWARE -d $CWD/$SOURCE/$LINUXSOURCE/firmware || exit 1

		make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- sun7i_defconfig || exit 1

		# use proven config
		cp $CWD/$SOURCE/$LINUXCONFIG $CWD/$SOURCE/$LINUXSOURCE/.config

#		make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- menuconfig  || exit 1

		# this way of compilation is much faster. We can use multi threading here but not later
		make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- uImage modules || exit 1
		# make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
		# produce deb packages: image, headers, firmware, libc
		#make -j1 deb-pkg KDEB_PKGVERSION=$REVISION LOCALVERSION="-"$BOARD KBUILD_DEBARCH=armhf ARCH=arm DEBFULLNAME="$MAINTAINER" DEBEMAIL="$MAINTAINERMAIL" CROSS_COMPILE=arm-unknown-linux-gnueabihf-
		# ALTERNATIVE DEB_HOST_ARCH=armhf make-kpkg --rootcmd fakeroot --arch arm --cross-compile arm-linux-gnueabihf- --revision=$REVISION --append-to-version=-$BOARD --jobs 3 --overlay-dir $SRC/lib/scripts/build-kernel kernel_image

		# we need a name
		#CHOOSEN_KERNEL=linux-image-"$VER"-"$CONFIG_LOCALVERSION$BOARD"_"$REVISION"_armhf.deb
	
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- INSTALL_MOD_PATH=$CWD/$PKG/kernel-modules modules_install || exit 1
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- INSTALL_HDR_PATH=$CWD/$PKG/kernel-headers/usr headers_install || exit 1

		# adding custom firmware
		unzip -o $CWD/$SOURCE/$FIRMWARE1 -d $CWD/$PKG/kernel-modules/lib/firmware || exit 1
	else
		echo "ERROR: Source file $1 does not exists. Check fetch_from_github configuration."
		exit
	fi
	sync
}


build_pkg (){

	kernel_version VERSION
	ARCH="arm"
	BUILD=1
	PACKAGER="mara"

	# clean-up unnecessary files generated during install
	find "$CWD/$PKG/kernel-modules" "$CWD/$PKG/kernel-headers" \( -name .install -o -name ..install.cmd \) -delete

	# split install_modules -> firmware
	install -dm755 "${CWD}/${PKG}/kernel-firmware/lib"
	if [ -d ${CWD}/${PKG}/kernel-modules/lib/firmware ];then
		mv ${CWD}/${PKG}/kernel-modules/lib/firmware "${CWD}/${PKG}/kernel-firmware/lib"
	fi

	install -dm755 "${CWD}/${PKG}/kernel-sun7i/boot"
	install -m644 $CWD/$SOURCE/$LINUXSOURCE/arch/$ARCH/boot/uImage "${CWD}/${PKG}/kernel-sun7i/boot/uImage"
	cd ${CWD}/${PKG}/kernel-sun7i/
	makepkg -l n -c n ${CWD}/${PKG}/kernel-sun7i-${VERSION}-${ARCH}-${BUILD}${PACKAGER}.txz
	
	
	cd ${CWD}/${PKG}/kernel-modules/
	install -dm755 "${CWD}/${PKG}/kernel-modules/etc/udev/rules.d/"
	cat <<EOF >> "${CWD}/${PKG}/kernel-modules/etc/udev/rules.d/50-mali.rules"
KERNEL=="mali", MODE="0660", GROUP="video"
KERNEL=="ump", MODE="0660", GROUP="video"
EOF
	install -dm755 "${CWD}/${PKG}/kernel-modules/etc/rc.d/"
	echo -e "#!/bin/sh\n" > ${CWD}/${PKG}/kernel-modules/etc/rc.d/rc.modules
	for mod in $MODULES;do
		echo "/sbin/modprobe $mod" >> ${CWD}/${PKG}/kernel-modules/etc/rc.d/rc.modules
	done
	chmod 755 ${CWD}/${PKG}/kernel-modules/etc/rc.d/rc.modules
	cd ${CWD}/${PKG}/kernel-modules/lib/modules/$VERSION*
	rm build source
	ln -s /usr/include build
	ln -s /usr/include source
	cd ${CWD}/${PKG}/kernel-modules/
	makepkg -l n -c n ${CWD}/${PKG}/kernel-modules-${VERSION}-${ARCH}-${BUILD}${PACKAGER}.txz
	
	cd ${CWD}/${PKG}/kernel-headers/
	makepkg -l n -c n ${CWD}/${PKG}/kernel-headers-${VERSION}-${ARCH}-${BUILD}${PACKAGER}.txz
	
	cd ${CWD}/${PKG}/kernel-firmware/
	makepkg -l n -c n ${CWD}/${PKG}/kernel-firmware-${VERSION}-${ARCH}-${BUILD}${PACKAGER}.txz

}

#download
#compile_uboot
compile_kernel
build_pkg
