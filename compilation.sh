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
    git checkout $SUNXI_TOOLS_VERSION >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # for host
    make -s clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s all clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s fex2bin >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s bin2fex >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    mkdir -p "host"
    cp -a {fexc,fex2bin,bin2fex} "host/"

    # for destination
    make -s clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s all clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'fex2bin' CC=${CROSS}gcc >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'bin2fex' CC=${CROSS}gcc >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'nand-part' CC=${CROSS}gcc >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

compile_boot_loader (){
    message "" "compiling" "$BOOT_LOADER"
    cd $CWD/$BUILD/$SOURCE/$BOOT_LOADER >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    make ARCH=$ARCH CROSS_COMPILE=$CROSS clean >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ ! -z $BOOT_LOADER_VERSION ]]; then
        git checkout $BOOT_LOADER_VERSION >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    make ARCH=$ARCH $BOOT_LOADER_CONFIG CROSS_COMPILE=$CROSS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk3288 ]]; then
#        if [[ $KERNEL_SOURCE == next ]]; then
            # u-boot-firefly-rk3288 2016.03 package contains backports
            # of EFI support patches and fails to boot the kernel on the Firefly.
            sed 's/^\(CONFIG_EFI_LOADER=y\)/# CONFIG_EFI_LOADER is not set/' -i .config >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            # create RK3288UbootLoader.bin
            tools/mkimage -n rk3288 -T rkimage -d \
            spl/u-boot-spl-dtb.bin out && \
            cat out | openssl rc4 -K 7c4e0304550509072d2c7b38170d1711 > "RK3288UbootLoader${BOOT_LOADER_VERSION}.bin"
#        else
#            make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS_OLD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#        fi
        find -name "RK3288UbootLoader*" -exec install -D {} $CWD/$BUILD/$OUTPUT/$FLASH/{} \;
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
    message "" "compiling" "$LINUX_SOURCE"
    cd "$CWD/$BUILD/$SOURCE/$LINUX_SOURCE" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

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
    make CROSS_COMPILE=$CROSS clean || exit 1
    # use proven config
    install -D $CWD/config/kernel/$LINUX_CONFIG $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/.config || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk3288 ]]; then
        if [ "$KERNEL_SOURCE" != "next" ]; then
            # fix firmware /system /lib
            find drivers/net/wireless/rockchip_wlan/rkwifi/ -type f -exec \
            sed -i "s#\/system\/etc\/firmware\/#\/lib\/firmware\/#" {} \;

            # fix kernel version
            sed -i "/SUBLEVEL = 0/d" Makefile
        fi

#        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS zImage modules || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS $DEVICE_TREE_BLOB || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == sun* ]]; then
#        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS oldconfig
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS zImage modules || (message "err" "details" && exit 1) || exit 1

        if [[ "$KERNEL_SOURCE" == "next" ]]; then
            make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS $DEVICE_TREE_BLOB || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    make $CTHREADS O=$(pwd) ARCH=$ARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules modules_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS O=$(pwd) ARCH=$ARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$CWD/$BUILD/$PKG/kernel-modules firmware_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS O=$(pwd) ARCH=$ARCH CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$CWD/$BUILD/$PKG/kernel-headers/usr headers_install >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


build_kernel() {
    message "" "create" "kernel"
    # create resource for flash
    cd $CWD/$BUILD/$OUTPUT/$FLASH
    cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/zImage $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/dts/$SOCFAMILY-$BOARD_NAME.dtb > $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/zImage-dtb || exit 1
    $CWD/$BUILD/$OUTPUT/$TOOLS/mkkrnlimg -a $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/zImage-dtb kernel.img || exit 1
}


build_resource() {
    message "" "create" "resource"
    # create resource for flash
    cd $CWD/$BUILD/$OUTPUT/$FLASH
    $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/resource_tool $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/logo.bmp $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/dts/$BOARD_NAME-$SOCFAMILY.dtb || exit 1
}


build_boot() {
    message "" "create" "boot initrd"
    # create boot for flash
    tar xf $CWD/bin/initrd-tree.tar.xz -C $CWD/$BUILD/$SOURCE/
    cd $CWD/$BUILD/$SOURCE/

    sed -i "s#mmcblk[0-9]p[0-9]#$ROOT_DISK#" "$CWD/$BUILD/$SOURCE/initrd-tree/rootdev"

    find $CWD/$BUILD/$SOURCE/initrd-tree/ ! -path "./.git*" | cpio -H newc -ov > initrd.img

    if [[ $KERNEL_SOURCE == next ]]; then
        $CWD/$BUILD/$OUTPUT/$TOOLS/mkkrnlimg -a initrd.img $CWD/$BUILD/$OUTPUT/$FLASH/boot.img

        if [ -e $CWD/$BUILD/$SOURCE/initrd.img ];then
            rm $CWD/$BUILD/$SOURCE/initrd.img
        fi
    else
        $CWD/$BUILD/$OUTPUT/$TOOLS/mkbootimg \
                            --kernel $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/arm/boot/zImage \
                            --ramdisk $CWD/$BUILD/$SOURCE/initrd.img \
                            -o $CWD/$BUILD/$OUTPUT/$FLASH/boot.img >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [ -e $CWD/$BUILD/$SOURCE/initrd.img ];then
        rm $CWD/$BUILD/$SOURCE/initrd.img
    fi

}




