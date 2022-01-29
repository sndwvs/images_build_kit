#!/bin/bash



if [ -z $CWD ]; then
    exit
fi


build_kernel_pkg() {
    cd $SOURCE
    # get kernel version
    KERNEL_VERSION=$(get_version $SOURCE/$KERNEL_DIR)

    KERNEL=zImage
    [[ $KARCH == arm64 || $KARCH == riscv ]] && KERNEL=Image

    message "" "copy" "linux-firmware"
    # create linux firmware
    [[ ! -d "$BUILD/$PKG/kernel-modules/lib/firmware" ]] && mkdir -p $BUILD/$PKG/kernel-modules/lib/firmware
    rsync -a --exclude .git $SOURCE/$KERNEL_FIRMWARE_DIR/ $BUILD/$PKG/kernel-modules/lib/firmware/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # adding custom firmware
    if [[ $FIRMWARE == "yes" ]];then
        cp -vaf $CWD/blobs/firmware/* $BUILD/$PKG/kernel-modules/lib/firmware/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        [[ -d $CWD/blobs/firmware-${BOARD_NAME} ]] && ( cp -vaf $CWD/blobs/firmware-${BOARD_NAME}/* $BUILD/$PKG/kernel-modules/lib/firmware/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    fi

    message "" "copy" "kernel"
    # install kernel
    install -Dm644 $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/$KERNEL $BUILD/$PKG/kernel-${SOCFAMILY}/boot/vmlinuz-${KERNEL_VERSION}
    install -Dm644 $SOURCE/$KERNEL_DIR/System.map $BUILD/$PKG/kernel-${SOCFAMILY}/boot/System.map-${KERNEL_VERSION}
    install -Dm644 $SOURCE/$KERNEL_DIR/.config $BUILD/$PKG/kernel-${SOCFAMILY}/boot/config-${KERNEL_VERSION}
    if [[ $SOCFAMILY != bcm2* || $BOARD_NAME != x96_max_plus ]]; then
        # Make symlinks:
        ln -sf System.map-${KERNEL_VERSION} $BUILD/$PKG/kernel-${SOCFAMILY}/boot/System.map
        ln -sf config-${KERNEL_VERSION} $BUILD/$PKG/kernel-${SOCFAMILY}/boot/config
        ln -sf vmlinuz-${KERNEL_VERSION} $BUILD/$PKG/kernel-${SOCFAMILY}/boot/vmlinuz
        ln -sf vmlinuz-${KERNEL_VERSION} $BUILD/$PKG/kernel-${SOCFAMILY}/boot/$KERNEL
    else
        install -Dm644 $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/$KERNEL $BUILD/$PKG/kernel-${SOCFAMILY}/boot/$KERNEL
        install -Dm644 $SOURCE/$KERNEL_DIR/System.map $BUILD/$PKG/kernel-${SOCFAMILY}/boot/System.map
        install -Dm644 $SOURCE/$KERNEL_DIR/.config $BUILD/$PKG/kernel-${SOCFAMILY}/boot/config
    fi

    message "" "copy" "device tree blob"
    # add device tree
    install -m755 -d "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}"
    if [[ ${KARCH} == arm64 || ${KARCH} == riscv ]]; then
            [[ $SOCFAMILY == rk3* ]] && ( cp -a $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/rockchip/*.dtb \
              $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
            [[ $SOCFAMILY == sun* ]] && ( cp -a $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/allwinner/*.dtb \
              $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
            [[ $SOCFAMILY == jh71* ]] && ( cp -a $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/starfive/*.dtb \
              $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
            [[ $SOCFAMILY == meson* ]] && ( cp -a $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/amlogic/*.dtb \
              $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
            if [[ $SOCFAMILY == bcm2* ]]; then
                install -dm755 "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/overlays/"
                cp -av $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/broadcom/*.dtb \
                        $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
                cp -av $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/*.dtb $BUILD/$PKG/kernel-${SOCFAMILY}/boot/
                cp -av $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/overlays/{*.dtbo,README} \
                        $BUILD/$PKG/kernel-${SOCFAMILY}/boot/overlays/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
            # amlogic tv box
            if [[ $BOARD_NAME == x96_max_plus ]]; then
                install -m755 -d "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb"
                cp -av $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/*.dtb $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
    else
        cp -av $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/*.dtb \
              $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb-${KERNEL_VERSION}/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    [[ $SOCFAMILY != bcm2* || $BOARD_NAME != x96_max_plus ]] && ( ln -sf dtb-${KERNEL_VERSION} $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    cd "$CWD" # fix actual current directory
    # clean-up unnecessary files generated during install
    find "$BUILD/$PKG/kernel-modules" "$BUILD/$PKG/kernel-headers" \( -name .install -o -name ..install.cmd \) -delete >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    message "" "create" "kernel packages"
    # split install_modules -> firmware
    install -dm755 "$BUILD/$PKG/kernel-firmware/lib"
    if [ -d $BUILD/$PKG/kernel-modules/lib/firmware ];then
        cp -af "$BUILD/$PKG/kernel-modules/lib/firmware" "$BUILD/$PKG/kernel-firmware/lib"
        rm -rf "$BUILD/$PKG/kernel-modules/lib/firmware"
    fi

    cd $BUILD/$PKG/kernel-modules/

    if [[ ! -z $MODULES ]]; then
        install -dm755 "$BUILD/$PKG/kernel-modules/etc/rc.d/"
        echo -e "#!/bin/sh\n" > $BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules.local
        for mod in $MODULES;do
            echo "/sbin/modprobe $mod" >> $BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules.local
        done
        chmod 755 $BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules.local
    fi

    cd $BUILD/$PKG/kernel-modules/lib/modules/${KERNEL_VERSION}*
    rm build source
    ln -s /usr/src/linux-${KERNEL_VERSION} build
    ln -s /usr/src/linux-${KERNEL_VERSION} source


    # build kernel-source
    [[ ! -d "$BUILD/$PKG/kernel-source" ]] && mkdir -p $BUILD/$PKG/kernel-source/usr/src/linux-${KERNEL_VERSION}
    rsync -a --exclude .git --delete $SOURCE/$KERNEL_DIR/ $BUILD/$PKG/kernel-source/usr/src/linux-${KERNEL_VERSION}/
    cd $BUILD/$PKG/kernel-source/usr/src/linux-${KERNEL_VERSION}/
    make ARCH=$KARCH CROSS_COMPILE=$CROSS clean >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    # Make sure header files aren't missing...
    make ARCH=$KARCH CROSS_COMPILE=$CROSS prepare >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    # Don't package the kernel in the sources:
    find . -name "*Image" -exec rm "{}" \+
    # No need for these:
    rm -f .config.old .version
    find . -name "*.cmd" -exec rm -f "{}" \+ 
    rm .*.d
    cd ..
    ln -sf linux-${KERNEL_VERSION} linux

    if [[ $DISTR == sla* ]]; then
        # create kernel package
        cd $BUILD/$PKG/kernel-${SOCFAMILY}/ && mkdir "install"
        cat "$CWD/packages/kernel/slack-desc.kernel-template" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-${SOCFAMILY}/install/slack-desc"
        makepkg -l n -c n $BUILD/$PKG/kernel-${SOCFAMILY}-${KERNEL_VERSION/-/_}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # create kernel-modules package
        cd $BUILD/$PKG/kernel-modules/ && mkdir "install"
        cat "$CWD/packages/kernel/slack-desc.kernel-modules" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-modules/install/slack-desc"
        makepkg -l n -c n $BUILD/$PKG/kernel-modules-${SOCFAMILY}-${KERNEL_VERSION/-/_}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # create kernel-headers package
        cd $BUILD/$PKG/kernel-headers/ && mkdir "install"
        cat "$CWD/packages/kernel/slack-desc.kernel-headers" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-headers/install/slack-desc"
        makepkg -l n -c n $BUILD/$PKG/kernel-headers-${SOCFAMILY}-${KERNEL_VERSION/-/_}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # create kernel-firmware package
        cd $BUILD/$PKG/kernel-firmware/ && mkdir "install"
        cat "$CWD/packages/kernel/slack-desc.kernel-firmware" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-firmware/install/slack-desc"
        makepkg -l n -c n $BUILD/$PKG/kernel-firmware-${SOCFAMILY}-${KERNEL_VERSION/-/_}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # create kernel-source package
        cd $BUILD/$PKG/kernel-source/ && mkdir "install"
        cat "$CWD/packages/kernel/slack-desc.kernel-source" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-source/install/slack-desc"
        makepkg -l n -c n $BUILD/$PKG/kernel-source-${SOCFAMILY}-${KERNEL_VERSION/-/_}-noarch-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        cd $BUILD/$PKG

        # clear kernel packages directories
        [[ -d "$BUILD/$PKG/kernel-${SOCFAMILY}" ]] && \
            rm -rf "$BUILD/$PKG/kernel-${SOCFAMILY}" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        [[ -d "$BUILD/$PKG/kernel-modules" ]] && \
            rm -rf "$BUILD/$PKG/kernel-modules" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        [[ -d "$BUILD/$PKG/kernel-headers" ]] && \
            rm -rf "$BUILD/$PKG/kernel-headers" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        [[ -d "$BUILD/$PKG/kernel-firmware" ]] && \
            rm -rf "$BUILD/$PKG/kernel-firmware" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        [[ -d "$BUILD/$PKG/kernel-source" ]] && \
            rm -rf "$BUILD/$PKG/kernel-source" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


create_bootloader_pack(){
    message "" "create" "bootloader pack"
    cd $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/ || exit 1
    tar cJf $BUILD/$OUTPUT/$IMAGES/boot-${ROOTFS_VERSION}.tar.xz boot || exit 1
}


