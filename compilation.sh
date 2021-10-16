#!/bin/bash



if [ -z $CWD ]; then
    exit
fi


compile_boot_loader() {
    BOOT_LOADER_VERSION=$(get_version $SOURCE/$BOOT_LOADER_DIR)
    message "" "compiling" "$BOOT_LOADER_DIR $BOOT_LOADER_VERSION"
    cd $SOURCE/$BOOT_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    gcc_version "$CROSS" GCC_VERSION
    message "" "compiler" "gcc $GCC_VERSION"

    local ARCH=arm

    make ARCH=$ARCH CROSS_COMPILE=$CROSS clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make ARCH=$ARCH CROSS_COMPILE=$CROSS $BOOT_LOADER_CONFIG >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # added in name suffix
    change_name_version "-$SOCFAMILY"

    [[ ! -z $ATF && ! -z $BL31 ]] && export BL31=$SOURCE/$ATF_DIR/bl31.${BL31##*.}
    [[ ! -z $ATF && -z $BL31 ]] && export BL31=$SOURCE/$ATF_DIR/bl31.bin

    if [[ $SOCFAMILY == rk35* ]]; then
        [[ ! -z $ATF && ! -z $BL31 ]] && ln -fs $SOURCE/$ATF_DIR/bl31.${BL31##*.} bl31.${BL31##*.}
        [[ ! -z $ATF && ! -z $OPTEE ]] && ln -fs $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$OPTEE tee.bin
    fi

    # rockchip
    if [[ $SOCFAMILY == rk3[235]* ]]; then
        # u-boot-firefly-rk3288 2016.03 package contains backports
        # of EFI support patches and fails to boot the kernel on the Firefly.
        [[ $SOCFAMILY == rk3288 ]] && ( sed 's/^\(CONFIG_EFI_LOADER=y\)/# CONFIG_EFI_LOADER is not set/' \
                                            -i .config >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # for rk33: rockpro64, rock pi 4, pinebook pro, rock64, firefly-rk3399, rock pi e, helios64, orange pi 4, station m1
        # rk35: quartz64, rock 3, station p2/m2
        if [[ $BOARD_NAME == rockpro64     || $BOARD_NAME == rock_pi_4*     || $BOARD_NAME == pinebook_pro || \
              $BOARD_NAME == rock64        || $BOARD_NAME == firefly_rk3399 || $BOARD_NAME == rock_pi_e    || \
              $BOARD_NAME == helios64      || $BOARD_NAME == orange_pi_4*   || $BOARD_NAME == station_m1   || \
              $BOARD_NAME == quartz64      || $BOARD_NAME == rock_3         || $BOARD_NAME == station_*2      ]]; then
            make $CTHREADS ARCH=$ARCH u-boot.itb CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    # allwinner, broadcom, amlogic
    if [[ $SOCFAMILY == sun* || $SOCFAMILY == bcm2* || $SOCFAMILY == meson* ]]; then
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # uboot customization
    [[ $(type -t uboot_customization) == function ]] && uboot_customization

    # create bootloader
    [[ $(type -t create_uboot) == function ]] && create_uboot
}

compile_atf() {
    message "" "compiling" "$ATF_DIR $ATF_BRANCH"
    cd $SOURCE/$ATF_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ -z $BL31 && $SOCFAMILY == rk33* ]]; then
        make realclean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        CFLAGS='-gdwarf-2' \
        CROSS_COMPILE=$CROSS \
        M0_CROSS_COMPILE=$CROSS32 \
        make PLAT=$ATF_PLAT DEBUG=0 bl31 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == sun50* ]]; then
        make realclean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make PLAT=$ATF_PLAT DEBUG=0 bl31 >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == rk3* ]]; then
        if [[ -z $BL31 ]]; then
            ln -fs ./build/$ATF_PLAT/release/bl31/bl31.elf bl31.elf
            ln -fs ./build/$ATF_PLAT/release/bl31/bl31.elf bl31.bin
        else
            ln -fs $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$BL31 bl31.elf
            ln -fs $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$BL31 bl31.bin
            #[[ ! -z $BL32 ]] && ln -fs $SOURCE/$RKBIN_DIR/bin/${SOCFAMILY:0:4}/$BL32 bl32.bin
        fi
    elif [[ $SOCFAMILY == sun50* ]]; then
        [[ -e ./build/$ATF_PLAT/release/bl31.bin ]] && ln -fs ./build/$ATF_PLAT/release/bl31.bin bl31.bin
    fi

    if [[ $SOCFAMILY == rk33* ]]; then
        $SOURCE/$BOOT_LOADER_TOOLS_DIR/tools/trust_merger $CWD/config/atf/$SOCFAMILY/trust.ini >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 trust.img $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/trust.img >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}

compile_boot_tools() {
    BOOT_LOADER_TOOLS_VERSION=$(get_version $SOURCE/$BOOT_LOADER_TOOLS_DIR)
    message "" "compiling" "$BOOT_LOADER_TOOLS_DIR $BOOT_LOADER_TOOLS_VERSION"
    cd $SOURCE/$BOOT_LOADER_TOOLS_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $MARCH == "x86_64" && $SOCFAMILY == rk33* ]]; then
        ln -sf ../../rkbin/tools/boot_merger tools/boot_merger
        ln -sf ../../rkbin/tools/trust_merger tools/trust_merger
        return 0
    fi

    make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    if [[ $SOCFAMILY == rk33* ]]; then
        make ${SOCFAMILY}_defconfig >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS tools >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    if [[ $SOCFAMILY == meson* ]]; then
        make ${BOARD_NAME/_/}_defconfig >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}

compile_boot_packer_loader() {
    message "" "compiling" "$BOOT_PACKER_LOADER_DIR"
    cd $SOURCE/$BOOT_PACKER_LOADER_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS all >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

compile_kernel() {
    KERNEL_VERSION=$(get_version $SOURCE/$KERNEL_DIR)
    message "" "compiling" "$KERNEL_DIR $KERNEL_VERSION"
    cd "$SOURCE/$KERNEL_DIR" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    local KERNEL=zImage

    [[ $KARCH == arm64 ]] && local KERNEL=Image

    # delete previous creations
    if [[ $SOCFAMILY != rk3288 || $KERNEL_SOURCE != next ]]; then
        message "" "clean" "$KERNEL_DIR"
        make ARCH=$KARCH CROSS_COMPILE=$CROSS clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # use proven config
    install -D $CWD/config/kernel/$LINUX_CONFIG $SOURCE/$KERNEL_DIR/.config || (message "err" "details" && exit 1) || exit 1

    gcc_version "$CROSS" GCC_VERSION
    message "" "compiler" "gcc $GCC_VERSION"

    # added in name suffix
    change_name_version ""

    if [[ $SOCFAMILY == rk3* ]]; then
        # fix build firmware
        [[ -d $SOURCE/$KERNEL_DIR/firmware/brcm ]] && ( rsync -ar --ignore-existing $CWD/blobs/firmware/brcm/ -d $SOURCE/$KERNEL_DIR/firmware/brcm >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    fi

#    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS oldconfig || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $KERNEL modules 2>&1 | tee -a $LOG
    [[ ${PIPESTATUS[0]} != 0 ]] && ( message "err" "details" && exit 1 )
    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS dtbs || (message "err" "details" && exit 1) || exit 1

    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$BUILD/$PKG/kernel-modules modules_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$BUILD/$PKG/kernel-headers/usr headers_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


