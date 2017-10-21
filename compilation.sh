#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

compile_rk2918 (){
    message "" "compiling" "$RK2918_TOOLS"
    PROGRAMS="afptool img_unpack img_maker mkkrnlimg"
    cd $CWD/$BUILD/$SOURCE/$RK2918_TOOLS
    make $CTHREADS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    for p in $PROGRAMS;do
        message "" "copy" "program: $p"
        mv $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
    done
}

compile_rkflashtool (){
    message "" "compiling" "$RKFLASH_TOOLS"
    PROGRAMS="rkcrc rkflashtool rkmisc rkpad rkparameters rkparametersblock rkunpack rkunsign"
    cd $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS
    make clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    for p in $PROGRAMS;do
        message "" "copy" "program: $p"
        cp $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
    done
}

compile_mkbooting (){
    message "" "compiling" "$MKBOOTIMG_TOOLS"
    PROGRAMS="afptool img_maker mkbootimg unmkbootimg mkrootfs mkupdate mkcpiogz unmkcpiogz"
    cd $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS
    make clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    for p in $PROGRAMS;do
        message "" "copy" "program: $p"
        cp $p $CWD/$BUILD/$OUTPUT/$TOOLS/ || exit 1
    done
}

compile_sunxi_tools (){
    message "" "compiling" "$SUNXI_TOOLS"
    cd $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # for host
    make -s clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s all clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s fex2bin >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s bin2fex >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    mkdir -p "host"
    cp -a {sunxi-fexc,fex2bin,bin2fex} "host/"

    # for destination
    make -s clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s all clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'fex2bin' CC=${CROSS}cc >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'bin2fex' CC=${CROSS}cc >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'sunxi-nand-part' CC=${CROSS}cc >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

compile_boot_loader (){
    message "" "compiling" "$BOOT_LOADER"
    cd $CWD/$BUILD/$SOURCE/$BOOT_LOADER >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    [[ $KARCH == arm64 ]] && local CROSS=$CROSS64

    make ARCH=$ARCH CROSS_COMPILE=$CROSS clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    make ARCH=$ARCH $BOOT_LOADER_CONFIG CROSS_COMPILE=$CROSS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk3* ]]; then
        # u-boot-firefly-rk3288 2016.03 package contains backports
        # of EFI support patches and fails to boot the kernel on the Firefly.
        [[ $SOCFAMILY == rk3288 ]] && ( sed 's/^\(CONFIG_EFI_LOADER=y\)/# CONFIG_EFI_LOADER is not set/' \
                                            -i .config >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        # create bootloader
        create_uboot
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        if [ "$KERNEL_SOURCE" != "next" ] ; then
            # patch mainline uboot configuration to boot with old kernels
            if [ "$(cat $CWD/$BUILD/$SOURCE/$BOOT_LOADER/.config | grep CONFIG_ARMV7_BOOT_SEC_DEFAULT=y)" == "" ]; then
                echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $CWD/$BUILD/$SOURCE/$BOOT_LOADER/.config
                echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y" >> $CWD/$BUILD/$SOURCE/$BOOT_LOADER/.config
            fi
        fi
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}

compile_kernel (){
    message "" "compiling" "$KERNEL_DIR"
    cd "$CWD/$BUILD/$SOURCE/$KERNEL_DIR" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    local KERNEL=zImage

    if [[ $KARCH == arm64 ]]; then
        local CROSS=$CROSS64
        local KERNEL=Image
        local DEVICE_TREE_BLOB=dtbs
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        # Attempting to run 'firmware_install' with CONFIG_USB_SERIAL_TI=y when
        # using make 3.82 results in an error
        # make[2]: *** No rule to make target `/lib/firmware/./', needed by
        # `/lib/firmware/ti_3410.fw'.  Stop.
        if [[ $(grep '$(INSTALL_FW_PATH)/$$(dir %)' scripts/Makefile.fwinst) ]];then
            sed -i 's:$(INSTALL_FW_PATH)/$$(dir %):$$(dir $(INSTALL_FW_PATH)/%):' scripts/Makefile.fwinst
        fi
    fi

    # delete previous creations
    [[ $SOCFAMILY != rk3288 || $KERNEL_SOURCE != next ]] \
        && message "" "clean" "$KERNEL_DIR" \
        && make CROSS_COMPILE=$CROSS clean

    # use proven config
    install -D $CWD/config/kernel/$LINUX_CONFIG $CWD/$BUILD/$SOURCE/$KERNEL_DIR/.config || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk3* ]]; then
        if [ "$KERNEL_SOURCE" != "next" ]; then
            # fix firmware /system /lib
            find drivers/net/wireless/rockchip_wlan/rkwifi/ -type f -exec \
            sed -i "s#\/system\/etc\/firmware\/#\/lib\/firmware\/#" {} \;

            # fix kernel version
#            sed -i "/SUBLEVEL = 0/d" Makefile
        fi

        # fix build firmware
        rsync -ar --ignore-existing $CWD/bin/$FIRMWARE/brcm/ -d $CWD/$BUILD/$SOURCE/$KERNEL_DIR/firmware/brcm >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

#        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $KERNEL modules || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $DEVICE_TREE_BLOB || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == sun* ]]; then
#        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS oldconfig
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $KERNEL modules || (message "err" "details" && exit 1) || exit 1

        if [[ "$KERNEL_SOURCE" == "next" ]]; then
            make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $DEVICE_TREE_BLOB || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules modules_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules firmware_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$CWD/$BUILD/$PKG/kernel-headers/usr headers_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


