#!/bin/bash



if [ -z $CWD ]; then
    exit
fi


build_kernel_pkg() {
    # get kernel version
    kernel_version KERNEL_VERSION

    KERNEL=zImage
    [[ $KARCH == arm64 ]] && KERNEL=Image

    if [[ ! -z $FIRMWARE ]]; then
        [[ ! -d "$BUILD/$PKG/kernel-modules/lib/firmware" ]] && mkdir -p $BUILD/$PKG/kernel-modules/lib/firmware
        # adding custom firmware
        cp -a $CWD/blobs/$FIRMWARE/* -d $BUILD/$PKG/kernel-modules/lib/firmware/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # install kernel
    install -Dm644 $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/$KERNEL "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/$KERNEL"

    # adding custom firmware
    [[ ! -z $FIRMWARE ]] && ( cp -a $CWD/blobs/$FIRMWARE/* -d $BUILD/$PKG/kernel-modules/lib/firmware/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )


    # add device tree
    install -m755 -d "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/"
    if [[ ${KARCH} == arm64 ]]; then
            [[ $SOCFAMILY == rk3* ]] && ( cp -a $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/rockchip/*${SOCFAMILY}*dtb \
              $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    else
        cp -a $SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/*${SOCFAMILY}*dtb \
              $BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        if [[ $KERNEL_SOURCE != next ]];then
            if [[ $BOARD_NAME == cubietruck ]]; then
                # vga | screen0_output_type = 4
                sed 's#screen0_output_type = [0-9]#screen0_output_type = 4#' "$CWD/config/boards/$BOARD_NAME/$BOARD_NAME.fex" \
                    > "$SOURCE/$SUNXI_TOOLS/host/script-vga.fex"
                $SOURCE/$SUNXI_TOOLS/host/fex2bin "$SOURCE/$SUNXI_TOOLS/host/script-vga.fex" "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-vga.bin"
            fi

            # hdmi | screen0_output_type = 3
            sed 's#screen0_output_type = [0-9]#screen0_output_type = 3#' "$CWD/config/boards/$BOARD_NAME/$BOARD_NAME.fex" \
                > "$SOURCE/$SUNXI_TOOLS/host/script-hdmi.fex"
            $SOURCE/$SUNXI_TOOLS/host/fex2bin "$SOURCE/$SUNXI_TOOLS/host/script-hdmi.fex" "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-hdmi.bin"

            # add entries necessary for HDMI-to-DVI adapters
            sed -e 's#screen0_output_type = [0-9]#screen0_output_type = 3#' \
                -e '/\[hdmi_para\]/a hdcp_enable = 0\nhdmi_cts_compatibility = 1' "$CWD/config/boards/$BOARD_NAME/$BOARD_NAME.fex" \
                > "$SOURCE/$SUNXI_TOOLS/host/script-hdmi-to-dvi.fex"
            $SOURCE/$SUNXI_TOOLS/host/fex2bin "$SOURCE/$SUNXI_TOOLS/host/script-hdmi-to-dvi.fex" "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-hdmi-to-dvi.bin"

            cd "$BUILD/$PKG/kernel-${SOCFAMILY}/boot"
            ln -sf "script-$VIDEO_OUTPUT.bin" "script.bin"
            cd "$CWD"
        fi
    fi

    # u-boot config
    install -Dm644 $CWD/config/boot_scripts/boot-$SOCFAMILY.cmd "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"
    # u-boot serial inteface config
    sed -e "s:%DEVICE_TREE_BLOB%:${DEVICE_TREE_BLOB}:g" \
        -e "s:%SERIAL_CONSOLE%:${SERIAL_CONSOLE}:g" \
        -e "s:%SERIAL_CONSOLE_SPEED%:${SERIAL_CONSOLE_SPEED}:g" \
        -i "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"
    # compile boot script
    [[ -f $BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd ]] && ( $SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A arm -T script -d $BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd \
                                                                        "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.scr" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    # u-boot
    [[ -f "$CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt" ]] && install -Dm644 $CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/uEnv.txt.new"
    # change root disk if disk not default
    [[ -n ${ROOT_DISK##*mmcblk0p1} ]] && echo "rootdev=/dev/$ROOT_DISK" >> "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/uEnv.txt.new"
    cd "$CWD" # fix actual current directory
    # clean-up unnecessary files generated during install
    find "$BUILD/$PKG/kernel-modules" "$BUILD/$PKG/kernel-headers" \( -name .install -o -name ..install.cmd \) -delete
    message "" "create" "kernel pakages"
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
    ln -s /usr/include build
    ln -s /usr/include source


    # create kernel package
    cd $BUILD/$PKG/kernel-${SOCFAMILY}/ && mkdir "install"
    cat "$CWD/packages/kernel/slack-desc.kernel-template" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-${SOCFAMILY}/install/slack-desc"
    install -m644 -D "$CWD/packages/kernel/doinst.sh.kernel" "$BUILD/$PKG/kernel-${SOCFAMILY}/install/doinst.sh"
    if [[ $KERNEL_SOURCE = next ]]; then
        touch "$BUILD/$PKG/kernel-${SOCFAMILY}/boot/.next"
    else
        echo "rm boot/.next 2> /dev/null" >> "$BUILD/$PKG/kernel-${SOCFAMILY}/install/doinst.sh"
    fi
    makepkg -l n -c n $BUILD/$PKG/kernel-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # create kernel-modules package
    cd $BUILD/$PKG/kernel-modules/ && mkdir "install"
    cat "$CWD/packages/kernel/slack-desc.kernel-modules" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-modules/install/slack-desc"
    makepkg -l n -c n $BUILD/$PKG/kernel-modules-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # create kernel-headers package
    cd $BUILD/$PKG/kernel-headers/ && mkdir "install"
    cat "$CWD/packages/kernel/slack-desc.kernel-headers" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-headers/install/slack-desc"
    makepkg -l n -c n $BUILD/$PKG/kernel-headers-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # create kernel-firmware package
    cd $BUILD/$PKG/kernel-firmware/ && mkdir "install"
    cat "$CWD/packages/kernel/slack-desc.kernel-firmware" | sed "s:%SOCFAMILY%:${SOCFAMILY}:g" > "$BUILD/$PKG/kernel-firmware/install/slack-desc"
    makepkg -l n -c n $BUILD/$PKG/kernel-firmware-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

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
}


build_sunxi_tools() {
    message "" "build" "package ${SUNXI_TOOLS}"
    mkdir -p $BUILD/$PKG/${SUNXI_TOOLS}/{sbin,install}

    install -m644 -D "$CWD/packages/${SUNXI_TOOLS}/slack-desc" "$BUILD/$PKG/${SUNXI_TOOLS}/install/slack-desc"

    cp -P $SOURCE/${SUNXI_TOOLS}/{bin2fex,fex2bin,sunxi-fexc,sunxi-nand-part} \
          $BUILD/$PKG/${SUNXI_TOOLS}/sbin/

    cd $BUILD/$PKG/${SUNXI_TOOLS}/
    makepkg -l n -c n $BUILD/$PKG/${SUNXI_TOOLS}-git_$(date +%Y%m%d)_$(cat $SOURCE/${SUNXI_TOOLS}/.git/packed-refs | grep refs/remotes/origin/master | cut -b1-7)-${ARCH}-${PKG_BUILD}${PACKAGER}.txz \
    >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    [[ -d $BUILD/$PKG/${SUNXI_TOOLS} ]] && rm -rf $BUILD/$PKG/${SUNXI_TOOLS}
}


create_bootloader_pack(){
    message "" "create" "bootloader pack"
    cd $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/ || exit 1
    tar cJf $BUILD/$OUTPUT/$IMAGES/boot-${ROOTFS_VERSION}.tar.xz boot || exit 1
}


