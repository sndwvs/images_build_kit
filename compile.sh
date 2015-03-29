#!/bin/bash

set -e

CWD=$(pwd)

CTHREADS="-j6"

DEST=$CWD

URL_LINUX_UPGRADE_TOOL="http://dl.radxa.com/rock/tools/linux/"
LINUX_UPGRADE_TOOL="Linux_Upgrade_Tool_v1.21"
URL_XTOOLS_OLD="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7/+archive/master.tar.gz"
URL_XTOOLS="http://archlinuxarm.org/builder/xtools/x-tools7h.tar.xz"
XTOOLS_OLD="x-tools7h_old"
XTOOLS="x-tools7h"
URL_RK2918_TOOLS="https://github.com/TeeFirefly/"
RK2918_TOOLS="rk2918_tools"
URL_RKFLASH_TOOLS="https://github.com/neo-technologies/"
RKFLASH_TOOLS="rkflashtool"
URL_MKBOOTIMG_TOOLS="https://github.com/neo-technologies/"
MKBOOTIMG_TOOLS="rockchip-mkbootimg"
URL_BOOT_LOADER_SOURCE="https://github.com/linux-rockchip/"
BOOT_LOADER="u-boot-rockchip"
BOOT_LOADER_CONFIG="rk3288_defconfig"
URL_FIRMWARE="https://github.com/rkchrome/overlay/archive/"
FIRMWARE="master.zip"
URL_LINUX_SOURCE="https://bitbucket.org/T-Firefly/"
LINUX_SOURCE="firefly-rk3288-kernel"
LINUX_CONFIG="rk3288_config"
MODULES="mali_kbase gspca_main"
ROOTFS="slack-current-miniroot"
VERSION="09Mar15"
ROOT_DISK="mmcblk0p3"

SOURCE="source"
PKG="pkg"
OUTPUT="output"
TOOLS="tools"
FLASH="flash"

export PATH=$PATH:$CWD/${SOURCE}/$XTOOLS_OLD/bin:$CWD/${SOURCE}/$XTOOLS/arm-unknown-linux-gnueabihf/bin:$CWD/$OUTPUT/$TOOLS/
CROSS_OLD="arm-eabi-"
CROSS="arm-unknown-linux-gnueabihf-"

#rm -rf ${CWD}/{$SOURCE/{$XTOOLS,$XTOOLS_OLD},$PKG,$OUTPUT/{$TOOLS,$FLASH}}
#mkdir -p ${CWD}/{$SOURCE/{$XTOOLS,$XTOOLS_OLD},$PKG,$OUTPUT/{$TOOLS,$FLASH}}


download (){

	cd $CWD

	echo "------ Download $LINUX_UPGRADE_TOOL"
	wget -c --no-check-certificate $URL_LINUX_UPGRADE_TOOL/$LINUX_UPGRADE_TOOL.zip -O $SOURCE/$LINUX_UPGRADE_TOOL.zip || exit 1
	unzip -o $CWD/$SOURCE/$LINUX_UPGRADE_TOOL.zip -d $CWD/$SOURCE/ || exit 1

# 	echo "------ Download x-tools old"
# 	wget -c --no-check-certificate $URL_XTOOLS_OLD -O $SOURCE/$XTOOLS_OLD.tar.gz || exit 1
# 	tar xvf $SOURCE/$XTOOLS_OLD.tar.?z* -C $SOURCE/$XTOOLS_OLD
#
# 	echo "------ Download x-tools"
# 	wget -c --no-check-certificate $URL_XTOOLS -O $SOURCE/$XTOOLS.tar.xz || exit 1
# 	tar xvf $SOURCE/$XTOOLS.tar.?z* -C $SOURCE/
#
# 	echo "------ Download $RK2918_TOOLS"
# 	if [ -d $SOURCE/$RK2918_TOOLS ]; then
# 	    cd $SOURCE/$RK2918_TOOLS && git pull origin HEAD && cd $CWD
# 	else
# 	    git clone $URL_RK2918_TOOLS/$RK2918_TOOLS $SOURCE/$RK2918_TOOLS
# 	fi
#
# 	echo "------ Download $RKFLASH_TOOLS"
# 	if [ -d $SOURCE/$RKFLASH_TOOLS ]; then
# 	    cd $SOURCE/$RKFLASH_TOOLS && git pull origin HEAD && cd $CWD
# 	else
# 	    git clone $URL_RKFLASH_TOOLS/$RKFLASH_TOOLS $SOURCE/$RKFLASH_TOOLS
# 	fi
# 	
# 	echo "------ Download $MKBOOTIMG_TOOLS"
# 	if [ -d $SOURCE/$MKBOOTIMG_TOOLS ]; then
# 	    cd $SOURCE/$MKBOOTIMG_TOOLS && git pull origin HEAD && cd $CWD
# 	else
# 	    git clone $URL_MKBOOTIMG_TOOLS/$MKBOOTIMG_TOOLS $SOURCE/$MKBOOTIMG_TOOLS
# 	fi
#
# 	echo "------ Download $BOOT_LOADER"
# 	if [ -d $SOURCE/$BOOT_LOADER ]; then
# 	    cd $SOURCE/$BOOT_LOADER && git pull origin HEAD && cd $CWD
# 	else
# 	    git clone $URL_BOOT_LOADER_SOURCE/$BOOT_LOADER $SOURCE/$BOOT_LOADER || exit 1
# 	fi
#
# 	echo "------ Download $LINUX_SOURCE"
# 	if [ -d $SOURCE/$LINUX_SOURCE ]; then
# 	    cd $SOURCE/$LINUX_SOURCE && git pull origin HEAD && cd $CWD
# 	else
# 	    git clone $URL_LINUX_SOURCE/$LINUX_SOURCE $SOURCE/$LINUX_SOURCE
# 	fi
#
#         if [ ! -f $SOURCE/$FIRMWARE ]; then
#             echo "------ Download $FIRMWARE"
#             wget -c --no-check-certificate $URL_FIRMWARE/$FIRMWARE -O $SOURCE/$FIRMWARE
#         fi
}

kernel_version (){
	local VER
	VER=$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
	VER=$VER.$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
	EXTRAVERSION=$(cat $CWD/$SOURCE/$LINUX_SOURCE/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
	if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
	echo "------ Get kernel version $VER"
	eval "$1=\$VER"
}

compile_rk2918 (){
	echo "------ Compiling $RK2918_TOOLS"
	PROGRAMS="afptool img_unpack img_maker mkkrnlimg"
	cd $CWD/$SOURCE/$RK2918_TOOLS
	make $CTHREADS || exit 1

	for p in $PROGRAMS;do
		echo "copy program: $p"
		mv $p $CWD/$OUTPUT/$TOOLS/ || exit 1
	done
}

compile_rkflashtool (){
	echo "------ Compiling $RKFLASH_TOOLS"
	PROGRAMS="rkcrc rkflashtool rkmisc rkpad rkparameters rkparametersblock rkunpack rkunsign"
	cd $CWD/$SOURCE/$RKFLASH_TOOLS
	make clean || exit 1
	make $CTHREADS || exit 1

	for p in $PROGRAMS;do
		echo "copy program: $p"
		cp $p $CWD/$OUTPUT/$TOOLS/ || exit 1
	done
}

compile_mkbooting (){
	echo "------ Compiling $MKBOOTIMG_TOOLS"
	PROGRAMS="afptool img_maker mkbootimg unmkbootimg mkrootfs mkupdate mkcpiogz unmkcpiogz"
	cd $CWD/$SOURCE/$MKBOOTIMG_TOOLS
	make clean || exit 1
	make $CTHREADS || exit 1

	for p in $PROGRAMS;do
		echo "copy program: $p"
		cp $p $CWD/$OUTPUT/$TOOLS/ || exit 1
	done
}

compile_boot_loader (){
	echo "------ Compiling $BOOT_LOADER"
	cd $CWD/$SOURCE/$BOOT_LOADER
	make ARCH=arm CROSS_COMPILE=$CROSS_OLD clean || exit 1
	make ARCH=arm $BOOT_LOADER_CONFIG CROSS_COMPILE=$CROSS_OLD || exit 1
	make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS_OLD || exit 1
	find -name "RK3288UbootLoader*" -exec install -D {} $CWD/$OUTPUT/$FLASH/{} \;
}

compile_kernel (){
	if [ -d "$CWD/$SOURCE/$LINUX_SOURCE" ]; then
		echo "------ Compiling kernel"
		cd $CWD/$SOURCE/$LINUX_SOURCE

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
	
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$PKG/kernel-modules modules_install || exit 1
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$PKG/kernel-modules firmware_install || exit 1
		make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$CWD/$PKG/kernel-headers/usr headers_install || exit 1
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

	# split install_modules -> firmware
	install -dm755 "${CWD}/${PKG}/kernel-firmware/lib"
	if [ -d ${CWD}/${PKG}/kernel-modules/lib/firmware ];then
		mv ${CWD}/${PKG}/kernel-modules/lib/firmware "${CWD}/${PKG}/kernel-firmware/lib"
		# clean-up unnecessary files generated during install
		find "${CWD}/${PKG}/kernel-firmware/lib" \( -name .install -o -name ..install.cmd \) -delete
	fi
	
	# add firmware
	unzip -o $CWD/$SOURCE/$FIRMWARE -d $CWD/$SOURCE/ || exit 1
	cp -a $CWD/$SOURCE/overlay-master/overlay-rksdk/files-overlay-rk3288/system/etc/firmware ${CWD}/${PKG}/kernel-firmware/lib/


	cd ${CWD}/${PKG}/kernel-modules/

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

add_linux_upgrade_tool (){
	echo "------ Add $LINUX_UPGRADE_TOOL"
	# add tool for flash boot loader
	cp -a ${CWD}/$SOURCE/$LINUX_UPGRADE_TOOL/upgrade_tool ${CWD}/$OUTPUT/$TOOLS/
	cp -a ${CWD}/$SOURCE/$LINUX_UPGRADE_TOOL/config.ini ${CWD}/$OUTPUT/$TOOLS/
}

build_parameters (){
	echo "------ Create parameters"
	# add parameters for flash
	cat <<EOF >"$OUTPUT/$FLASH/parameters.txt"
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
	cd ${CWD}/$OUTPUT/$FLASH
	${CWD}/$SOURCE/$LINUX_SOURCE/resource_tool ${CWD}/$SOURCE/$LINUX_SOURCE/logo.bmp ${CWD}/$SOURCE/$LINUX_SOURCE/arch/arm/boot/dts/firefly-rk3288.dtb
}

build_boot (){
	echo "------ Create boot"
	# create boot for flash
	cd ${CWD}/$SOURCE/
	${CWD}/$OUTPUT/$TOOLS/mkcpiogz initrd-tree
	${CWD}/$OUTPUT/$TOOLS/mkbootimg --kernel ${CWD}/$SOURCE/$LINUX_SOURCE/arch/arm/boot/zImage --ramdisk initrd-tree.cpio.gz -o ${CWD}/$OUTPUT/$FLASH/boot.img
	if [ -e ${CWD}/$SOURCE/initrd-tree.cpio.gz ];then
		rm ${CWD}/$SOURCE/initrd-tree.cpio.gz
	fi
}


build_flash_script (){
	echo "------ Create flash script"
	cat <<EOF >"${CWD}/$OUTPUT/$FLASH/flash.sh"
#!/bin/sh

if [ "$EUID" -ne 0 ];then
	echo "Please run as root"
	exit
fi

echo "------ flash boot loader"
${CWD}/$OUTPUT/$TOOLS/upgrade_tool ul \$(ls | grep RK3288UbootLoader)
echo "------ flash parameters"
${CWD}/$OUTPUT/$TOOLS/rkflashtool P < parameters.txt || exit 1
echo "------ flash resource"
${CWD}/$OUTPUT/$TOOLS/rkflashtool w resource < resource.img || exit 1
echo "------ flash boot"
${CWD}/$OUTPUT/$TOOLS/rkflashtool w boot < boot.img || exit 1
echo "------ flash rootfs"
${CWD}/$OUTPUT/$TOOLS/rkflashtool w linuxroot < ${ROOTFS}_${VERSION}.img || exit 1
echo "------ reboot device"
${CWD}/$OUTPUT/$TOOLS/rkflashtool b RK320A
EOF
chmod 755 "${CWD}/$OUTPUT/$FLASH/flash.sh"
}

download
#compile_rk2918
#compile_rkflashtool
#compile_mkbooting
#compile_boot_loader
#compile_kernel
#build_pkg
add_linux_upgrade_tool
build_parameters
build_resource
build_boot
build_flash_script
