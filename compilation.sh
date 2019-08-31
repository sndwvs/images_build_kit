#!/bin/bash



if [ -z $CWD ]; then
    exit
fi


compile_sunxi_tools() {
    message "" "compiling" "$SUNXI_TOOLS"
    cd $SOURCE/$SUNXI_TOOLS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # for host
    make -s clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s all clean CROSS_COMPILE='' >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s fex2bin >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s bin2fex >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    mkdir -p "host"
    cp -a {sunxi-fexc,fex2bin,bin2fex} "host/"

    # for destination
    make -s clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make -s all clean CROSS_COMPILE='' >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'fex2bin' CC=${CROSS}gcc >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'bin2fex' CC=${CROSS}gcc >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS 'sunxi-nand-part' CC=${CROSS}gcc >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

compile_boot_loader() {
    message "" "compiling" "$BOOT_LOADER_DIR $BOOT_LOADER_BRANCH"
    cd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

#    [[ $KARCH == arm64 ]] && local CROSS=$CROSS64

    gcc_version "$CROSS" GCC_VERSION
    message "" "version" "$GCC_VERSION"

    local ARCH=arm

    make ARCH=$ARCH CROSS_COMPILE=$CROSS clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    make ARCH=$ARCH $BOOT_LOADER_CONFIG CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # added in name suffix
    change_name_version "-$SOCFAMILY"

    if [[ $SOCFAMILY == rk3* ]]; then
        # u-boot-firefly-rk3288 2016.03 package contains backports
        # of EFI support patches and fails to boot the kernel on the Firefly.
        [[ $SOCFAMILY == rk3288 ]] && ( sed 's/^\(CONFIG_EFI_LOADER=y\)/# CONFIG_EFI_LOADER is not set/' \
                                            -i .config >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # for rockpro64, rock pi 4
        if [[ $BOARD_NAME == rockpro64 || $BOARD_NAME == rock_pi_4 ]]; then
            make $CTHREADS ARCH=$ARCH u-boot.itb CROSS_COMPILE=$CROSS BL31=$SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$BL31 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        if [ "$KERNEL_SOURCE" != "next" ] ; then
            # patch mainline uboot configuration to boot with old kernels
            if [ "$(cat $SOURCE/$BOOT_LOADER_DIR/.config | grep CONFIG_ARMV7_BOOT_SEC_DEFAULT=y)" == "" ]; then
                echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $SOURCE/$BOOT_LOADER_DIR/.config
                echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y" >> $SOURCE/$BOOT_LOADER_DIR/.config
            fi
        fi
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # create bootloader
    create_uboot
}

compile_atf() {
    message "" "compiling" "$ATF_DIR $ATF_BRANCH"
    cd $SOURCE/$ATF_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == rk33* && $NATIVE_ARCH != true ]]; then
        make realclean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        CFLAGS='-gdwarf-2' \
        CROSS_COMPILE=$CROSS \
        M0_CROSS_COMPILE=$CROSS32 \
        make PLAT=$SOCFAMILY DEBUG=0 bl31 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ ! -z $BL31 && $NATIVE_ARCH == true ]]; then
        ln -fs $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$BL31 bl31.elf
    else
        ln -fs ./build/$SOCFAMILY/release/bl31/bl31.elf bl31.elf
    fi

    $SOURCE/$BOOT_LOADER_TOOLS_DIR/tools/trust_merger $CWD/config/atf/$SOCFAMILY/trust.ini >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    install -Dm644 trust.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

compile_boot_tools() {
    message "" "compiling" "$BOOT_LOADER_TOOLS_DIR $BOOT_LOADER_TOOLS_BRANCH"
    cd $SOURCE/$BOOT_LOADER_TOOLS_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make ${SOCFAMILY}_defconfig >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS tools >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


compile_kernel() {
    message "" "compiling" "$KERNEL_DIR"
    cd "$SOURCE/$KERNEL_DIR" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    local KERNEL=zImage

    if [[ $KARCH == arm64 ]]; then
        [[ $SOCFAMILY == rk33* ]] && local CROSS=$OLD_CROSS
        local KERNEL=Image
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
    if [[ $SOCFAMILY != rk3288 || $KERNEL_SOURCE != next ]]; then
        message "" "clean" "$KERNEL_DIR"
        make CROSS_COMPILE=$CROSS clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # use proven config
    install -D $CWD/config/kernel/$LINUX_CONFIG $SOURCE/$KERNEL_DIR/.config || (message "err" "details" && exit 1) || exit 1

    [[ "$KERNEL_SOURCE" != next && $SOCFAMILY == sun* ]] && local CROSS=$OLD_CROSS
    gcc_version "$CROSS" GCC_VERSION
    message "" "version" "$GCC_VERSION"

    # added in name suffix
    change_name_version ""

    if [[ $SOCFAMILY == rk3* ]]; then
        # fix build firmware
        [[ -d $SOURCE/$KERNEL_DIR/firmware/brcm ]] && ( rsync -ar --ignore-existing $CWD/blobs/$FIRMWARE/brcm/ -d $SOURCE/$KERNEL_DIR/firmware/brcm >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

#        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $KERNEL modules | tee $LOG
        [[ ${PIPESTATUS[0]} != 0 ]] && ( message "err" "details" && exit 1 )
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS dtbs || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == sun* ]]; then
#        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS oldconfig
        make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $KERNEL modules || (message "err" "details" && exit 1) || exit 1

        if [[ "$KERNEL_SOURCE" == "next" ]]; then
            make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS dtbs || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$BUILD/$PKG/kernel-modules modules_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    [[ "$KERNEL_SOURCE" != next ]] && ( make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$BUILD/$PKG/kernel-modules firmware_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$BUILD/$PKG/kernel-headers/usr headers_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


