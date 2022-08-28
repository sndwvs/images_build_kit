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

    # uboot prepare
    [[ $(type -t uboot_prepare) == function ]] && uboot_prepare

    if [[ $ARCH == arm* || $ARCH == aarch* ]]; then
        local ARCH=arm
    elif [[ $ARCH == riscv* ]]; then
        local ARCH=riscv
    fi

    make ARCH=$ARCH CROSS_COMPILE=$CROSS clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make ARCH=$ARCH CROSS_COMPILE=$CROSS $BOOT_LOADER_CONFIG >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # added in name suffix
    change_name_version "-$SOCFAMILY"

    # for build u-boot.itb
    export BL31=$SOURCE/$ATF_DIR/bl31.elf

    if [[ $SOCFAMILY == sun20* ]]; then
        [[ ! -z $OPENSBI && ! -z $OPENSBI_BLOB ]] && ln -fs $SOURCE/$OPENSBI_DIR/$OPENSBI_BLOB $OPENSBI_BLOB
    fi

    # rockchip
    if [[ $SOCFAMILY == rk3[235]* ]]; then
        # u-boot-firefly-rk3288 2016.03 package contains backports
        # of EFI support patches and fails to boot the kernel on the Firefly.
        [[ $SOCFAMILY == rk3288 ]] && ( sed 's/^\(CONFIG_EFI_LOADER=y\)/# CONFIG_EFI_LOADER is not set/' \
                                            -i .config >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # completely open components
        if [[ ${BOOT_LOADER_BUILD_TYPE} != "blobs" && $SOCFAMILY != rk32* ]]; then
            make $CTHREADS ARCH=$ARCH u-boot.itb CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    # starfive
    if [[ $SOCFAMILY == jh7100 ]]; then
        make $CTHREADS ARCH=$ARCH u-boot.bin u-boot.dtb CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # allwinner, broadcom, amlogic
    if [[ $SOCFAMILY == sun* || $SOCFAMILY == bcm2* || $SOCFAMILY == meson* ]]; then
        make $CTHREADS ARCH=$ARCH CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # uboot customization
    [[ $(type -t uboot_customization) == function ]] && uboot_customization

    # create bootloader
    [[ $(type -t create_uboot) == function ]] && create_uboot

    unset BL31
}

compile_atf() {
    message "" "compiling" "$ATF_DIR $ATF_BRANCH"
    cd $SOURCE/$ATF_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ ${BOOT_LOADER_BUILD_TYPE} != "blobs" && ${BOOT_LOADER_BUILD_TYPE} != "atf-blob" && $SOCFAMILY == rk33* ]]; then
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
}

compile_opensbi() {
    message "" "compiling" "$OPENSBI_DIR $OPENSBI_BRANCH"
    cd $SOURCE/$OPENSBI_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == sun20* ]]; then
        make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS CROSS_COMPILE=$CROSS PLATFORM=$OPENSBI_PLATFORM FW_PIC=y BUILD_INFO=y >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        ln -fs $SOURCE/$OPENSBI_DIR/build/platform/$OPENSBI_PLATFORM/firmware/$OPENSBI_BLOB $OPENSBI_BLOB
    fi
    if [[ $SOCFAMILY == jh7100 ]]; then
        make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS CROSS_COMPILE=$CROSS PLATFORM=$OPENSBI_PLATFORM FW_PAYLOAD_PATH=../${BOOT_LOADER_DIR}/u-boot.bin FW_FDT_PATH=../${BOOT_LOADER_DIR}/u-boot.dtb >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        ln -fs $SOURCE/$OPENSBI_DIR/build/platform/$OPENSBI_PLATFORM/firmware/$OPENSBI_BLOB $OPENSBI_BLOB
    fi
}

compile_second_boot() {
    message "" "compiling" "$SECOND_BOOT_DIR $SECOND_BOOT_BRANCH"
    cd $SOURCE/$SECOND_BOOT_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [[ $SOCFAMILY == sun20* ]]; then
        #make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS CROSS_COMPILE=$CROSS p=$SOCFAMILY mmc >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 nboot/boot0_sdcard_${SOCFAMILY}.bin $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/boot0_sdcard_${SOCFAMILY}.bin >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    if [[ $SOCFAMILY == jh7100 ]]; then
        cd build >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        make $CTHREADS CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        #install -Dm644 boot0_sdcard_${SOCFAMILY}.bin $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/boot0_sdcard_${SOCFAMILY}.bin >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}

compile_ddrinit() {
    message "" "compiling" "$DDRINIT_DIR $DDRINIT_BRANCH"
    cd $SOURCE/$DDRINIT_DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    cd build >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS CROSS_COMPILE=$CROSS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    #install -Dm644 nboot/boot0_sdcard_${SOCFAMILY}.bin $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot/boot0_sdcard_${SOCFAMILY}.bin >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
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

    [[ $KARCH == arm64 || $KARCH == riscv ]] && local KERNEL=Image

    # delete previous creations
    if [[ $SOCFAMILY != rk3288 || $KERNEL_SOURCE != next ]]; then
        message "" "clean" "$KERNEL_DIR"
        make ARCH=$KARCH CROSS_COMPILE=$CROSS clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # use proven config
    install -Dm644 $CWD/config/kernel/$LINUX_CONFIG $SOURCE/$KERNEL_DIR/.config || (message "err" "details" && exit 1) || exit 1

    gcc_version "$CROSS" GCC_VERSION
    message "" "compiler" "gcc $GCC_VERSION"

    # added in name suffix
    change_name_version ""

    if [[ $SOCFAMILY == rk3* ]]; then
        # fix build firmware
        [[ -d $SOURCE/$KERNEL_DIR/firmware/brcm ]] && ( rsync -ar --ignore-existing $CWD/blobs/firmware/overall/brcm/ -d $SOURCE/$KERNEL_DIR/firmware/brcm >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    fi

#    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS menuconfig  || exit 1
    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS oldconfig || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS $KERNEL modules 2>&1 | tee -a $LOG
    [[ ${PIPESTATUS[0]} != 0 ]] && ( message "err" "details" && exit 1 )
    make $CTHREADS ARCH=$KARCH CROSS_COMPILE=$CROSS dtbs 2>&1 | tee -a $LOG
    [[ ${PIPESTATUS[0]} != 0 ]] && ( message "err" "details" && exit 1 )

    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_MOD_PATH=$BUILD/$PKG/kernel-modules modules_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make $CTHREADS O=$(pwd) ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_HDR_PATH=$BUILD/$PKG/kernel-headers/usr headers_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    make ARCH=$KARCH CROSS_COMPILE=$CROSS INSTALL_PATH=$BUILD/$PKG/kernel-${SOCFAMILY}/boot dtbs_install >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


