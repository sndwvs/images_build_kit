#!/bin/bash

set -e

CWD=$(pwd)

CTHREADS=" -j7  "

DEST=$CWD


if [ "$1" == "next" ];then
  NEXT=$1
fi

URLXTOOLS="http://archlinuxarm.org/builder/xtools"
XTOOLS="x-tools7h.tar.xz"
URLSUNXITOOLS="https://github.com/linux-sunxi"
SUNXITOOLS="sunxi-tools"
FIRMWARE="ap6210.zip"
FIRMWARE1="linux-firmware.zip"
FIRMWARESOURCE="https://github.com/igorpecovnik/lib/raw/next/bin"
BOOTLOADER="https://github.com/linux-sunxi"
URL_BOOT_LOADER_SOURCE="git://git.denx.de/u-boot.git"
BOOT_LOADER="u-boot-sunxi"
BOOT_LOADER_CONFIG="Cubietruck_defconfig"
BOOT_LOADER_BIN="u-boot-sunxi-with-spl.bin"
URL_LINUX_SOURCE="https://github.com/dan-and"
URL_LINUX_NEXT_SOURCE="http://mirror.yandex.ru/pub/linux/kernel/v4.x/"
LINUX_NEXT_SOURCE="linux-4.0.8"
LINUX_NEXT_CONFIG="linux-sunxi-next.config"
LINUX_SOURCE="linux-sunxi"
LINUX_CONFIG="linux-sunxi.config"
URL_LINUX_CONFIG_SOURCE="https://github.com/igorpecovnik/lib/raw/next/config"
MODULES="hci_uart gpio_sunxi bt_gpio wifi_gpio rfcomm hidp sunxi-ir bonding spi_sun7i bcmdhd ump mali mali_drm"

SOURCE="source"
PKG="pkg"
OUTPUT="output"


export PATH=$PATH:$CWD/${SOURCE}/arm-unknown-linux-gnueabihf/bin:$CWD/$OUTPUT/$BOOT_LOADER/

if [ "$NEXT" = "next" ];then
    LINUX_SOURCE=$LINUX_NEXT_SOURCE
    LINUX_CONFIG=$LINUX_NEXT_CONFIG
fi

clean(){
    rm -rf ${CWD}/{$PKG,$OUTPUT}
    mkdir -p ${CWD}/{$SOURCE,$PKG,$OUTPUT}
}


download(){

	cd $CWD

	if [ -f $SOURCE/$XTOOLS ];then
	    echo "------ Remove x-tools"
#	    rm $SOURCE/$XTOOLS
	fi
	echo "------ Download x-tools"
#	wget -c --no-check-certificate $URLXTOOLS/$XTOOLS -O $SOURCE/$XTOOLS
#	tar xfv $SOURCE/$XTOOLS --strip-components=1 -C $SOURCE/

	echo "------ Download $BOOT_LOADER"
	if [ -d $SOURCE/$BOOT_LOADER ];then
	    cd $SOURCE/$BOOT_LOADER && git pull && cd $CWD
	else
	    git clone $URL_BOOT_LOADER_SOURCE $SOURCE/$BOOT_LOADER
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

	if [ "$NEXT" == "next" ];then
	    if [ ! -f $SOURCE/$LINUX_SOURCE ]; then
		echo "------ Download $LINUX_SOURCE"
		wget -c --no-check-certificate $URL_LINUX_NEXT_SOURCE/$LINUX_SOURCE.tar.xz -O $SOURCE/$LINUX_SOURCE.tar.xz
	    fi
	    if [ ! -f $SOURCE/$LINUX_CONFIG ]; then
		echo "------ Download $LINUX_CONFIG"
		wget -c --no-check-certificate $URL_LINUX_CONFIG_SOURCE/$LINUX_CONFIG -O $SOURCE/$LINUX_CONFIG
	    fi
	    if [ ! -d "$CWD/$SOURCE/$LINUX_SOURCE" ]; then
		echo "------ Extract kernel"
		tar xf $CWD/$SOURCE/$LINUX_SOURCE.tar.?z* -C $CWD/$SOURCE || exit 1
	    fi
	fi

	if [ "$NEXT" != "next" ];then
	    if [ ! -f $SOURCE/$LINUX_CONFIG ]; then
		echo "------ Download $LINUX_CONFIG"
		wget --no-check-certificate $URL_LINUX_CONFIG_SOURCE/$LINUX_CONFIG -O $SOURCE/$LINUX_CONFIG
	    fi

	    echo "------ Download $LINUX_SOURCE"
	    if [ -d $SOURCE/$LINUX_SOURCE ]; then
		cd $SOURCE/$LINUX_SOURCE && git pull origin HEAD && cd $CWD
	    else
		git clone $URL_LINUX_SOURCE/$LINUX_SOURCE $SOURCE/$LINUX_SOURCE
	    fi
	fi
}

kernel_version (){
	local VER
	VER=$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
	EXTRA_VERSION=$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
	if [ "$EXTRA_VERSION" != "=" ]; then VER=$VER$EXTRA_VERSION; fi
	echo "------ Get kernel version $VER"
	eval "$1=\$VER"
}

compile_boot_loader (){
	echo "------ Compiling $BOOT_LOADER"
	cd $CWD/$SOURCE/$BOOT_LOADER
#	make -s CROSS_COMPILE=arm-unknown-linux-gnueabihf- clean || exit 1

	make $CTHREADS $BOOT_LOADER_CONFIG CROSS_COMPILE=arm-unknown-linux-gnueabihf- || exit 1
	if [ "$NEXT" != "next" ] ; then
		## patch mainline uboot configuration to boot with old kernels
		if [ "$(cat $CWD/$SOURCE/$BOOT_LOADER/.config | grep CONFIG_ARMV7_BOOT_SEC_DEFAULT=y)" == "" ]; then
			echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $CWD/$SOURCE/$BOOT_LOADER/.config
			echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $CWD/$SOURCE/$BOOT_LOADER/spl/.config
			echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y" >> $CWD/$SOURCE/$BOOT_LOADER/.config
			echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y"	>> $CWD/$SOURCE/$BOOT_LOADER/spl/.config
		fi
	fi
	make $CTHREADS CROSS_COMPILE=arm-unknown-linux-gnueabihf- || exit 1

	install -dm755 $CWD/$OUTPUT/$BOOT_LOADER || exit 1
	cp {tools/mkimage,$BOOT_LOADER_BIN} $CWD/$OUTPUT/$BOOT_LOADER/ || exit 1
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

compile_next_kernel (){
	echo "------ Compiling kernel"
	cd $CWD/$SOURCE/$LINUX_SOURCE

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
	unzip -o $CWD/$SOURCE/$FIRMWARE -d $CWD/$SOURCE/$LINUX_SOURCE/firmware || exit 1

	make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- sunxi_defconfig || exit 1

	# use proven config
	cp $CWD/$SOURCE/$LINUX_CONFIG $CWD/$SOURCE/$LINUX_SOURCE/.config

#	make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- menuconfig  || exit 1

	# this way of compilation is much faster. We can use multi threading here but not later
	make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- zImage dtbs modules || exit 1
#	make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- sun7i-a20-cubietruck.dtb || exit 1
	# make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

	make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- INSTALL_MOD_PATH=$CWD/$PKG/kernel-modules modules_install || exit 1
	make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- INSTALL_HDR_PATH=$CWD/$PKG/kernel-headers/usr headers_install || exit 1

	# adding custom firmware
	unzip -o $CWD/$SOURCE/$FIRMWARE1 -d $CWD/$PKG/kernel-modules/lib/firmware || exit 1
}

compile_kernel (){
	if [ -d "$CWD/$SOURCE/$LINUX_SOURCE" ]; then
		echo "------ Compiling kernel"
		cd $CWD/$SOURCE/$LINUX_SOURCE

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
		unzip -o $CWD/$SOURCE/$FIRMWARE -d $CWD/$SOURCE/$LINUX_SOURCE/firmware || exit 1

		make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- sun7i_defconfig || exit 1

		# use proven config
		cp $CWD/$SOURCE/$LINUX_CONFIG $CWD/$SOURCE/$LINUX_SOURCE/.config

#		make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- menuconfig  || exit 1

		# this way of compilation is much faster. We can use multi threading here but not later
		make $CTHREADS ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- zImage modules || exit 1
		# make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- INSTALL_MOD_PATH=$CWD/$PKG/kernel-modules modules_install || exit 1
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabihf- INSTALL_HDR_PATH=$CWD/$PKG/kernel-headers/usr headers_install || exit 1

		# adding custom firmware
		unzip -o $CWD/$SOURCE/$FIRMWARE1 -d $CWD/$PKG/kernel-modules/lib/firmware || exit 1
	else
		echo "ERROR: Source file $1 does not exists. Check fetch_from_github configuration."
		exit
	fi
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

	install -Dm644 $CWD/$SOURCE/$LINUX_SOURCE/arch/$ARCH/boot/zImage "${CWD}/${PKG}/kernel-sun7i/boot/zImage"

	cat > "${CWD}/${PKG}/kernel-sun7i/boot/boot.cmd" << EOF
setenv bootargs 'console=tty0,115200 root=/dev/mmcblk0p1 ro rootwait rootfstype=ext4 sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=16 hdmi.audio=EDID:0 disp.screen0_output_mode=1920x1280p60 panic=10 consoleblank=0 enforcing=0 loglevel=1'
#--------------------------------------------------------------------------------------------------------------------------------
# Boot loader script to boot with different boot methods for old and new kernel
#--------------------------------------------------------------------------------------------------------------------------------
if ext4load mmc 0 0x00000000 /boot/.next
then
# sunxi mainline kernel
#--------------------------------------------------------------------------------------------------------------------------------
ext4load mmc 0 0x49000000 /boot/dtb/sun7i-a20-cubietruck.dtb
ext4load mmc 0 0x46000000 /boot/zImage
env set fdt_high ffffffff
bootz 0x46000000 - 0x49000000
#--------------------------------------------------------------------------------------------------------------------------------
else
# sunxi old kernel
#--------------------------------------------------------------------------------------------------------------------------------
ext4load mmc 0 0x43000000 /boot/script.bin
ext4load mmc 0 0x48000000 /boot/zImage
bootz 0x48000000
#--------------------------------------------------------------------------------------------------------------------------------
fi
EOF

	install -dm755 "${CWD}/${PKG}/kernel-sun7i/install/"
	cat > "${CWD}/${PKG}/kernel-sun7i/install/doinst.sh" << EOF
rm /boot/.next 2> /dev/null
EOF

	$CWD/$SOURCE/$BOOT_LOADER/tools/mkimage -C none -A arm -T script -d ${CWD}/${PKG}/kernel-sun7i/boot/boot.cmd "${CWD}/${PKG}/kernel-sun7i/boot/boot.scr" || exit 1
	install -Dm644 "$CWD/$OUTPUT/$BOOT_LOADER/$BOOT_LOADER_BIN" "${CWD}/${PKG}/kernel-sun7i/boot/u-boot-sunxi-with-spl.bin"
	cd ${CWD}/${PKG}/kernel-sun7i/
	if [ "$NEXT" == "next" ];then
	    install -Dm644 $CWD/$SOURCE/$LINUX_SOURCE/arch/$ARCH/boot/dts/sun7i-a20-cubietruck.dtb "${CWD}/${PKG}/kernel-sun7i/boot/dtb/sun7i-a20-cubietruck.dtb" || exit 1
	    touch boot/.next
	fi
	makepkg -l n -c n ${CWD}/${PKG}/kernel-sun7i-${VERSION}-${ARCH}-${BUILD}${PACKAGER}.txz

	if [ "$NEXT" != "next" ];then
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
	fi
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


patching_sources (){
#--------------------------------------------------------------------------------------------------------------------------------
# Patching kernel sources
#--------------------------------------------------------------------------------------------------------------------------------
echo "------ Patching kernel"
    cd $CWD/$SOURCE/$LINUX_SOURCE

    # mainline
    if [ "$NEXT" = "next" ];then
	# Fix BRCMFMAC AP mode for Cubietruck / Banana PRO
	if [ "$(cat drivers/net/wireless/brcm80211/brcmfmac/feature.c | grep "mbss\", 0);\*")" == "" ]; then
		sed -i 's/brcmf_feat_iovar_int_set(ifp, BRCMF_FEAT_MBSS, "mbss", 0);/\/*brcmf_feat_iovar_int_set(ifp, BRCMF_FEAT_MBSS, "mbss", 0);*\//g' drivers/net/wireless/brcm80211/brcmfmac/feature.c
	fi
	
	# install device tree blobs in separate package, link zImage to kernel image script
	wget -c --no-check-certificate https://raw.githubusercontent.com/igorpecovnik/lib/next/patch/packaging-next.patch -O $CWD/$SOURCE/packaging-next.patch
	if [ "$(patch --dry-run -t -p1 < $CWD/$SOURCE/packaging-next.patch | grep previ)" == "" ]; then
		patch -p1 < $CWD/$SOURCE/packaging-next.patch || exit 1
	fi
    fi

    # sunxi 3.4
    if [ "$NEXT" != "next" ];then
	# SPI functionality
        wget -c --no-check-certificate https://raw.githubusercontent.com/igorpecovnik/lib/next/patch/spi.patch -O $CWD/$SOURCE/spi.patch
	if [ "$(patch --dry-run -t -p1 < $CWD/$SOURCE/spi.patch | grep previ)" == "" ]; then
	    patch --batch -f -p1 < $CWD/$SOURCE/spi.patch || exit 1
	fi

	# compiler reverse patch. It has already been fixed.
	wget -c --no-check-certificate https://raw.githubusercontent.com/igorpecovnik/lib/next/patch/compiler.patch -O $CWD/$SOURCE/compiler.patch
	if [ "$(patch --dry-run -t -p1 < $CWD/$SOURCE/compiler.patch | grep Reversed)" != "" ]; then
	    patch --batch -t -p1 < $CWD/$SOURCE/compiler.patch || exit 1
	fi
    fi

    # u-boot
    cd $CWD/$SOURCE/$BOOT_LOADER
    echo "------ Patching $BOOT_LOADER"

    # Add awsom to uboot
    wget -c --no-check-certificate https://raw.githubusercontent.com/igorpecovnik/lib/next/patch/add-awsom-uboot.patch -O $CWD/$SOURCE/add-awsom-uboot.patch
    if [ "$(patch --dry-run -t -p1 < $CWD/$SOURCE/add-awsom-uboot.patch | grep create)" == "" ]; then
	    patch --batch -N -p1 < $CWD/$SOURCE/add-awsom-uboot.patch || exit 1
    fi
}

#clean
download
#patching_sources
compile_boot_loader
#compile_sunxi_tools
#if [ "$NEXT" == "next" ];then
#    compile_next_kernel
#else
#    compile_kernel
#fi
build_pkg

