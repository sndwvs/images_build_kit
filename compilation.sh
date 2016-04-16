#!/bin/bash



if [ -z $CWD ];then
    exit
fi

#---------------------------------------------
# create dir
#---------------------------------------------
download (){

    message "" "download" "$XTOOLS"
    wget -c --no-check-certificate $URL_XTOOLS -O $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

    message "" "extract" "$XTOOLS"
    tar xpf $CWD/$BUILD/$SOURCE/$XTOOLS.tar.?z* -C "$CWD/$BUILD/$SOURCE/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

    message "" "download" "$BOOT_LOADER"
    if [ -d $CWD/$BUILD/$SOURCE/$BOOT_LOADER ]; then
	cd $CWD/$BUILD/$SOURCE/$BOOT_LOADER $CWD/$BUILD/$SOURCE/$BOOT_LOADER && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    else
	git clone $URL_BOOT_LOADER_SOURCE/${BOOT_LOADER}.git $CWD/$BUILD/$SOURCE/$BOOT_LOADER >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    fi

    message "" "download" "$LINUX_SOURCE"
    if [[ -z $NEXT ]];then
        if [ -d $CWD/$BUILD/$SOURCE/$LINUX_SOURCE ]; then
	    cd $CWD/$BUILD/$SOURCE/$LINUX_SOURCE && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        else
	    git clone $URL_LINUX_SOURCE/$LINUX_SOURCE $CWD/$BUILD/$SOURCE/$LINUX_SOURCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi
    else
        wget -c --no-check-certificate $URL_LINUX_SOURCE/$LINUX_SOURCE.tar.xz -O $CWD/$BUILD/$SOURCE/$LINUX_SOURCE.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

        message "" "extract" "$LINUX_SOURCE"
        tar xpf $CWD/$BUILD/$SOURCE/$LINUX_SOURCE.tar.xz -C "$CWD/$BUILD/$SOURCE/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    fi

#    if [[ ! -f $CWD/$BUILD/$SOURCE/$FIRMWARE && ! -z $FIRMWARE ]]; then
#        message "" "download" "$FIRMWARE"
#        wget -c --no-check-certificate $URL_FIRMWARE/$FIRMWARE -O $CWD/$BUILD/$SOURCE/$FIRMWARE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
#    fi

    if [ "$BOARD_NAME" = "firefly" ];then
        message "" "download" "$LINUX_UPGRADE_TOOL"
        wget -c --no-check-certificate $URL_LINUX_UPGRADE_TOOL/$LINUX_UPGRADE_TOOL.zip -O $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL.zip >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        unzip -o $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL.zip -d $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

        message "" "download" "$URL_XTOOLS_OLD"
        if [ -d $CWD/$BUILD/$SOURCE/$XTOOLS_OLD ]; then
            cd $CWD/$BUILD/$SOURCE/$XTOOLS_OLD && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        else
            git clone $URL_XTOOLS_OLD $CWD/$BUILD/$SOURCE/$XTOOLS_OLD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi

        message "" "download" "$RK2918_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$RK2918_TOOLS ]; then
            cd $CWD/$BUILD/$SOURCE/$RK2918_TOOLS && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        else
            git clone $URL_RK2918_TOOLS/$RK2918_TOOLS $CWD/$BUILD/$SOURCE/$RK2918_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi

        message "" "download" "$RKFLASH_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS ]; then
            cd $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        else
            git clone $URL_RKFLASH_TOOLS/$RKFLASH_TOOLS $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi

        message "" "download" "$MKBOOTIMG_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS ]; then
            cd $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        else
            git clone $URL_MKBOOTIMG_TOOLS/$MKBOOTIMG_TOOLS $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi
    fi

    if [ "$BOARD_NAME" = "cubietruck" ]; then
        message "" "download" "$SUNXI_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS ];then
            cd $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        else
            git clone $URL_SUNXI_TOOLS/$SUNXI_TOOLS $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi

        if [ ! -f $CWD/$BUILD/$SOURCE/$FIRMWARE1 ]; then
            message "" "download" "$FIRMWARE1"
            wget -c --no-check-certificate $URL_FIRMWARE/$FIRMWARE1 -O $CWD/$BUILD/$SOURCE/$FIRMWARE1 >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        fi
    fi
}

compile_rk2918 (){
    message "" "compiling" "$RK2918_TOOLS"
    PROGRAMS="afptool img_unpack img_maker mkkrnlimg"
    cd $CWD/$BUILD/$SOURCE/$RK2918_TOOLS
    make $CTHREADS || exit 1

    for p in $PROGRAMS;do
	echo "copy program: $p"
	mv $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
    done
}

compile_rkflashtool (){
    message "" "compiling" "$RKFLASH_TOOLS"
    PROGRAMS="rkcrc rkflashtool rkmisc rkpad rkparameters rkparametersblock rkunpack rkunsign"
    cd $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS
    make clean || exit 1
    make $CTHREADS || exit 1

    for p in $PROGRAMS;do
        message "" "copy" "program: $p"
        cp $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
    done
}

compile_mkbooting (){
    message "" "compiling" "$MKBOOTIMG_TOOLS"
    PROGRAMS="afptool img_maker mkbootimg unmkbootimg mkrootfs mkupdate mkcpiogz unmkcpiogz"
    cd $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS
    make clean || exit 1
    make $CTHREADS || exit 1

    for p in $PROGRAMS;do
        message "" "copy" "program: $p"
        cp $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
    done
}

compile_sunxi_tools (){
    message "" "compiling" "$SUNXI_TOOLS"
    cd $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    git checkout $SUNXI_TOOLS_VERSION >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

    # for host
    make -s clean && make -s all clean && make -s fex2bin && make -s bin2fex || exit 1

    # for destination
    make -s clean && make -s all clean && make $CTHREADS 'fex2bin' CC=${CROSS}gcc || exit 1
    make $CTHREADS 'bin2fex' CC=${CROSS}gcc && make $CTHREADS 'nand-part' CC=${CROSS}gcc || exit 1
}

compile_boot_loader (){
    message "" "compiling" "$BOOT_LOADER"
    cd $CWD/$BUILD/$SOURCE/$BOOT_LOADER >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    git checkout $BOOT_LOADER_VERSION >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

    if [ "$BOARD_NAME" == "firefly" ]; then
        make ARCH=arm CROSS_COMPILE=$CROSS_OLD clean || exit 1
        make ARCH=arm $BOOT_LOADER_CONFIG CROSS_COMPILE=$CROSS_OLD || exit 1
        make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS_OLD || exit 1
        find -name "RK3288UbootLoader*" -exec install -D {} $CWD/$BUILD/$OUTPUT/$FLASH/{} \;
    fi

    if [ "$BOARD_NAME" == "cubietruck" ]; then
        make ARCH=arm CROSS_COMPILE=$CROSS clean || exit 1
        make ARCH=arm $BOOT_LOADER_CONFIG CROSS_COMPILE=$CROSS || exit 1

	if [ "$NEXT" != "next" ] ; then
	    ## patch mainline uboot configuration to boot with old kernels
	    if [ "$(cat $CWD/$BUILD/$SOURCE/$BOOT_LOADER/.config | grep CONFIG_ARMV7_BOOT_SEC_DEFAULT=y)" == "" ]; then
	        echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $CWD/$BUILD/$SOURCE/$BOOT_LOADER/.config
	        echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $CWD/$BUILD/$SOURCE/$BOOT_LOADER/spl/.config
	        echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y" >> $CWD/$BUILD/$SOURCE/$BOOT_LOADER/.config
	        echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y" >> $CWD/$BUILD/$SOURCE/$BOOT_LOADER/spl/.config
	    fi
	fi

        make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS || exit 1
    fi
}

compile_kernel (){
    message "" "compiling" "$LINUX_SOURCE"
    cd "$CWD/$BUILD/$SOURCE/$LINUX_SOURCE" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

    if [ "$BOARD_NAME" == "firefly" ]; then
        # fix firmware /system /lib
        find drivers/net/wireless/rockchip_wlan/rkwifi/ -type f -exec \
        sed -i "s#\/system\/etc\/firmware\/#\/lib\/firmware\/#" {} \;

        # fix kernel version
        sed -i "/SUBLEVEL = 0/d" Makefile

        DEFCONFIG="firefly-rk3288-linux_defconfig"
    fi

    if [ "$BOARD_NAME" == "cubietruck" ]; then	    
        # Attempting to run 'firmware_install' with CONFIG_USB_SERIAL_TI=y when
        # using make 3.82 results in an error
        # make[2]: *** No rule to make target `/lib/firmware/./', needed by
        # `/lib/firmware/ti_3410.fw'.  Stop.
        if [[ `grep '$(INSTALL_FW_PATH)/$$(dir %)' scripts/Makefile.fwinst` ]];then
            sed -i 's:$(INSTALL_FW_PATH)/$$(dir %):$$(dir $(INSTALL_FW_PATH)/%):' scripts/Makefile.fwinst
        fi

        if [ "$NEXT" == "next" ]; then
            DEFCONFIG="sunxi_defconfig"
        else
            DEFCONFIG="sun7i_defconfig"
        fi
    fi

    # delete previous creations
    make CROSS_COMPILE=$CROSS clean || exit 1

    if [ "$BOARD_NAME" == "firefly" ]; then
        make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS $DEFCONFIG || exit 1
CROSS=$CROSS_OLD
#        patching_kernel_config

#		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS menuconfig  || exit 1

		# this way of compilation is much faster. We can use multi threading here but not later
#		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS zImage modules || exit 1
#		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS firefly-rk3288.dtb || exit 1
    fi
	    
	    
	if [ "$BOARD_NAME" == "cubietruck" ]; then
	    if [[ ! -z $FIRMWARE ]]; then
                # adding custom firmware to kernel source
                echo A | unzip -o $CWD/$BUILD/$SOURCE/$FIRMWARE -d $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/firmware >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
            fi

            # use proven config
            install -D $CWD/config/$LINUX_CONFIG $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/.config

#		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS menuconfig  || exit 1
#		make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS zImage modules || exit 1
       fi

#	    make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS menuconfig  || exit 1
       make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS oldconfig
       make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS zImage modules || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

       if [[ "$BOARD_NAME" == "cubietruck" && "$NEXT" == "next" ]]; then
           make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS sun7i-a20-cubietruck.dtb || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
       elif [ "$BOARD_NAME" == "firefly" ]; then
           make $CTHREADS ARCH=arm CROSS_COMPILE=$CROSS firefly-rk3288.dtb || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
       fi

       make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules modules_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
       make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules firmware_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
       make $CTHREADS O=$(pwd) ARCH=arm CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$CWD/$BUILD/$PKG/kernel-headers/usr headers_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
}

build_kernel_pkg (){
	kernel_version _VERSION
#	_ARCH="arm"
#	_BUILD=1
#	_PACKAGER="mara"
	if [ "$BOARD_NAME" == "firefly" ]; then
            _KERNEL="rk3288"

	    # add firmware
	    unzip -o $CWD/$BUILD/$SOURCE/$FIRMWARE -d $CWD/$BUILD/$SOURCE/ || exit 1
#	    cp -a $CWD/$BUILD/$SOURCE/overlay-master/overlay-rksdk/files-overlay-rk3288/system/etc/firmware $CWD/$BUILD/$PKG/kernel-modules/lib/ || exit 1  
	    cp -a $CWD/$BUILD/$SOURCE/hwpacks-master/system/etc/firmware $CWD/$BUILD/$PKG/kernel-modules/lib/ || exit 1  
	fi

	if [ "$BOARD_NAME" == "cubietruck" ]; then
            _KERNEL="sun7i"

	    # adding custom firmware
	    unzip -o $CWD/$BUILD/$SOURCE/$FIRMWARE1 -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware || exit 1

	    install -Dm644 $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/$_ARCH/boot/zImage "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/zImage"

	    cat > "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/boot.cmd" << EOF
setenv bootargs 'console=tty0,115200 root=/dev/$ROOT_DISK ro rootwait rootfstype=ext4 sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=16 hdmi.audio=EDID:0 disp.screen0_output_mode=1920x1080p60 panic=10 consoleblank=0 enforcing=0 loglevel=8'
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

	    $CWD/$BUILD/$SOURCE/$BOOT_LOADER/tools/mkimage -C none -A arm -T script -d $CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/boot.cmd "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/boot.scr" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
	    install -Dm644 "$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/$BOOT_LOADER_BIN"

	    if [ "$NEXT" == "next" ];then
                install -Dm644 $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/$_ARCH/boot/dts/sun7i-a20-cubietruck.dtb "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/dtb/sun7i-a20-cubietruck.dtb" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
                touch "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/.next"
	    else

	        install -Dm644 "$CWD/config/script-hdmi.bin" "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/script-hdmi.bin"
	        install -Dm644 "$CWD/config/script-vga.bin" "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/script-vga.bin"

	        cd "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/boot/"
	        if [ -e $HDMI ];then
	            ln -sf "script-vga.bin" "script.bin"
	        else
                    ln -sf "script-hdmi.bin" "script.bin"
	        fi
	        cd "$CWD"

                install -dm755 "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/install/"
                cat > "$CWD/$BUILD/$PKG/kernel-${_KERNEL}/install/doinst.sh" << EOF
rm /boot/.next 2> /dev/null
EOF
            fi
	fi

	# clean-up unnecessary files generated during install
	find "$CWD/$BUILD/$PKG/kernel-modules" "$CWD/$BUILD/$PKG/kernel-headers" \( -name .install -o -name ..install.cmd \) -delete

	message "" "create" "kernel pakages"
	# split install_modules -> firmware
	install -dm755 "$CWD/$BUILD/$PKG/kernel-firmware/lib"
	if [ -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware ];then
		cp -af "$CWD/$BUILD/$PKG/kernel-modules/lib/firmware" "$CWD/$BUILD/$PKG/kernel-firmware/lib"
		rm -rf "$CWD/$BUILD/$PKG/kernel-modules/lib/firmware"
	fi


	cd $CWD/$BUILD/$PKG/kernel-modules/

	install -dm755 "$CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/"
	echo -e "#!/bin/sh\n" > $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules
	for mod in $MODULES;do
	    echo "/sbin/modprobe $mod" >> $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules
	done
	chmod 755 $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules
	cd $CWD/$BUILD/$PKG/kernel-modules/lib/modules/$_VERSION*
	rm build source
	ln -s /usr/include build
	ln -s /usr/include source

	if [ "$BOARD_NAME" == "cubietruck" ]; then
        cd $CWD/$BUILD/$PKG/kernel-${_KERNEL}/
        makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-${_KERNEL}-${_VERSION}-${_ARCH}-${_BUILD}${_PACKAGER}.txz
	fi

    cd $CWD/$BUILD/$PKG/kernel-modules/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-modules-${_KERNEL}-${_VERSION}-${_ARCH}-${_BUILD}${_PACKAGER}.txz
	
	cd $CWD/$BUILD/$PKG/kernel-headers/
	makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-headers-${_KERNEL}-${_VERSION}-${_ARCH}-${_BUILD}${_PACKAGER}.txz
	
	cd $CWD/$BUILD/$PKG/kernel-firmware/
	makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-firmware-${_KERNEL}-${_VERSION}-${_ARCH}-${_BUILD}${_PACKAGER}.txz
}

add_linux_upgrade_tool (){
    message "" "add" "$LINUX_UPGRADE_TOOL"
    # add tool for flash boot loader
    cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/upgrade_tool $CWD/$BUILD/$OUTPUT/$TOOLS/
    cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/config.ini $CWD/$BUILD/$OUTPUT/$TOOLS/
}

build_parameters (){
    message "" "create" "parameters"
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
    message "" "create" "resource"
	# create resource for flash
	cd $CWD/$BUILD/$OUTPUT/$FLASH
	$CWD/$BUILD/$SOURCE/$LINUX_SOURCE/resource_tool $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/logo.bmp $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/dts/firefly-rk3288.dtb || exit 1
}

build_boot (){
    message "" "create" "boot initrd"
	# create boot for flash
	tar xf $CWD/bin/initrd-tree.tar.xz -C $CWD/$BUILD/$SOURCE/
	cd $CWD/$BUILD/$SOURCE/
	$CWD/$BUILD/$OUTPUT/$TOOLS/mkcpiogz $CWD/$BUILD/$SOURCE/initrd-tree || exit 1
	$CWD/$BUILD/$OUTPUT/$TOOLS/mkbootimg \
	                    --kernel $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/zImage \
	                    --ramdisk $CWD/$BUILD/$SOURCE/initrd-tree.cpio.gz \
	                    -o $CWD/$BUILD/$OUTPUT/$FLASH/boot.img >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
	if [ -e $CWD/$BUILD/$SOURCE/initrd-tree.cpio.gz ];then
		rm $CWD/$BUILD/$SOURCE/initrd-tree.cpio.gz
	fi
}


build_flash_script (){
    message "" "create" "flash script"
    cat <<EOF >"$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh"
#!/bin/sh

if [ "$EUID" -ne 0 ];then
    echo "Please run as root"
    exit
fi

case "\$1" in
    -r )
    shift
    XFCE="false"
    ;;
    --xfce )
    shift
    XFCE="true"
    ;;
    *)
    echo -e "Options:"
    echo -e "\t-r"
    echo -e "\t\tflash mini rootfs image without xfce"

    echo -e "\t--xfce"
    echo -e "\t\tflash image with xfce\n"
    exit
    ;;
esac


if [ -f $TOOLS-$(uname -m).tar.xz ];then
    echo "------ unpack $TOOLS"
    tar xf $TOOLS-$(uname -m).tar.xz || exit 1
fi
echo "------ flash boot loader"
$TOOLS/upgrade_tool ul \$(ls | grep RK3288UbootLoader) || exit 1
echo "------ flash parameters"
$TOOLS/rkflashtool P < parameters.txt || exit 1
echo "------ flash resource"
$TOOLS/rkflashtool w resource < resource.img || exit 1
echo "------ flash boot"
$TOOLS/rkflashtool w boot < boot.img || exit 1
if [ "\$XFCE" = "true" ]; then
    echo "------ flash linuxroot $ROOTFS_XFCE.img"
    $TOOLS/rkflashtool w linuxroot < $ROOTFS_XFCE.img || exit 1
else
    echo "------ flash linuxroot $ROOTFS.img"
    $TOOLS/rkflashtool w linuxroot < $ROOTFS.img || exit 1
fi
echo "------ reboot device"
$TOOLS/rkflashtool b RK320A || exit 1
EOF
chmod 755 "$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh"
}

create_tools_pack(){
    message "" "create" "tools pack"
    cd $CWD/$BUILD/$OUTPUT/ || exit 1
    tar cJf $CWD/$BUILD/$OUTPUT/$FLASH/$TOOLS-$(uname -m).tar.xz $TOOLS || exit 1
}



