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
        [[ ! -d "$CWD/$BUILD/$PKG/kernel-modules/lib/firmware" ]] && mkdir -p $CWD/$BUILD/$PKG/kernel-modules/lib/firmware
        # adding custom firmware
        cp -a $CWD/blobs/$FIRMWARE/* -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # install kernel
    install -Dm644 $CWD/$BUILD/$SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/$KERNEL "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/$KERNEL"

    # adding custom firmware
#    unzip -o $CWD/blobs/$BOARD_NAME/$FIRMWARE -d $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#    cp -a $CWD/$BUILD/$SOURCE/hwpacks-master/system/etc/firmware $CWD/$BUILD/$PKG/kernel-modules/lib/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    [[ ! -z $FIRMWARE ]] && ( cp -a $CWD/blobs/$FIRMWARE/* -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )


    # add device tree
    [[ ! -z $DEVICE_TREE_BLOB && $ARCH == arm ]] && ( install -Dm644 $CWD/$BUILD/$SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/$DEVICE_TREE_BLOB \
                                                        "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/$DEVICE_TREE_BLOB" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    [[ $SOCFAMILY == rk33* ]] && ( install -Dm644 $CWD/$BUILD/$SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/rockchip/$DEVICE_TREE_BLOB \
                                    "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/$DEVICE_TREE_BLOB" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    if [[ $SOCFAMILY == sun* ]]; then
        if [[ $KERNEL_SOURCE != next ]];then
            if [[ $BOARD_NAME == cubietruck ]]; then
                # vga | screen0_output_type = 4
                sed 's#screen0_output_type = [0-9]#screen0_output_type = 4#' "$CWD/config/boards/$BOARD_NAME/$BOARD_NAME.fex" \
                    > "$CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/script-vga.fex"
                $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/fex2bin "$CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/script-vga.fex" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-vga.bin"
            fi

            # hdmi | screen0_output_type = 3
            sed 's#screen0_output_type = [0-9]#screen0_output_type = 3#' "$CWD/config/boards/$BOARD_NAME/$BOARD_NAME.fex" \
                > "$CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/script-hdmi.fex"
            $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/fex2bin "$CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/script-hdmi.fex" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-hdmi.bin"

            # add entries necessary for HDMI-to-DVI adapters
            sed -e 's#screen0_output_type = [0-9]#screen0_output_type = 3#' \
                -e '/\[hdmi_para\]/a hdcp_enable = 0\nhdmi_cts_compatibility = 1' "$CWD/config/boards/$BOARD_NAME/$BOARD_NAME.fex" \
                > "$CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/script-hdmi-to-dvi.fex"
            $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/fex2bin "$CWD/$BUILD/$SOURCE/$SUNXI_TOOLS/host/script-hdmi-to-dvi.fex" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-hdmi-to-dvi.bin"

            cd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot"
            ln -sf "script-$VIDEO_OUTPUT.bin" "script.bin"
            cd "$CWD"
        fi
    fi

    # u-boot config
    install -Dm644 $CWD/config/boot_scripts/boot-$SOCFAMILY.cmd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"
    # u-boot serial inteface config
    sed -e "s:%SERIAL_CONSOLE%:${SERIAL_CONSOLE}:g" \
        -e "s:%SERIAL_CONSOLE_SPEED%:${SERIAL_CONSOLE_SPEED}:g" \
        -i "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"
    # compile boot script
    [[ -f $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd ]] && ( $CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR/tools/mkimage -C none -A arm -T script -d $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd \
                                                                        "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.scr" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    # u-boot
    [[ -f "$CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt" ]] && install -Dm644 $CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/uEnv.txt.new"
    # change root disk if disk not default
    [[ -n ${ROOT_DISK##*mmcblk0p1} ]] && echo "rootdev=/dev/$ROOT_DISK" >> "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/uEnv.txt.new"

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

    if [[ ! -z $MODULES ]]; then
        install -dm755 "$CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/"
        echo -e "#!/bin/sh\n" > $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules.local
        for mod in $MODULES;do
            echo "/sbin/modprobe $mod" >> $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules.local
        done
        chmod 755 $CWD/$BUILD/$PKG/kernel-modules/etc/rc.d/rc.modules.local
    fi

    cd $CWD/$BUILD/$PKG/kernel-modules/lib/modules/${KERNEL_VERSION}*
    rm build source
    ln -s /usr/include build
    ln -s /usr/include source


    # create kernel package
    cd $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/
    install -m644 -D "$CWD/packages/kernel/slack-desc.kernel-template" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/slack-desc"
    sed -i "s:%PACKAGE_NAME%:kernel-${SOCFAMILY}:g" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/slack-desc"
    install -m644 -D "$CWD/packages/kernel/doinst.sh.kernel" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/doinst.sh"
    if [[ $KERNEL_SOURCE = next ]]; then
        touch "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/.next"
    else
        echo "rm boot/.next 2> /dev/null" >> "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/doinst.sh"
    fi
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # create kernel-modules package
    cd $CWD/$BUILD/$PKG/kernel-modules/
    install -m644 -D "$CWD/packages/kernel/slack-desc.kernel-modules" "$CWD/$BUILD/$PKG/kernel-modules/install/slack-desc"
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-modules-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # create kernel-headers package
    cd $CWD/$BUILD/$PKG/kernel-headers/
    install -m644 -D "$CWD/packages/kernel/slack-desc.kernel-headers" "$CWD/$BUILD/$PKG/kernel-headers/install/slack-desc"
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-headers-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    # create kernel-firmware package
    cd $CWD/$BUILD/$PKG/kernel-firmware/
    install -m644 -D "$CWD/packages/kernel/slack-desc.kernel-firmware" "$CWD/$BUILD/$PKG/kernel-firmware/install/slack-desc"
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-firmware-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    cd $CWD/$BUILD/$PKG

    # clear kernel packages directories
    [[ -d "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}" ]] && \
        rm -rf "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    [[ -d "$CWD/$BUILD/$PKG/kernel-modules" ]] && \
        rm -rf "$CWD/$BUILD/$PKG/kernel-modules" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    [[ -d "$CWD/$BUILD/$PKG/kernel-headers" ]] && \
        rm -rf "$CWD/$BUILD/$PKG/kernel-headers" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    [[ -d "$CWD/$BUILD/$PKG/kernel-firmware" ]] && \
        rm -rf "$CWD/$BUILD/$PKG/kernel-firmware" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


build_sunxi_tools() {
    message "" "build" "package ${SUNXI_TOOLS}"
    mkdir -p $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/{sbin,install}

    install -m644 -D "$CWD/packages/${SUNXI_TOOLS}/slack-desc" "$CWD/$BUILD/$PKG/${SUNXI_TOOLS}/install/slack-desc"

    cp -P $CWD/$BUILD/$SOURCE/${SUNXI_TOOLS}/{bin2fex,fex2bin,sunxi-fexc,sunxi-nand-part} \
          $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/sbin/

    cd $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/
    makepkg -l n -c n $CWD/$BUILD/$PKG/${SUNXI_TOOLS}-git_$(date +%Y%m%d)_$(cat $CWD/$BUILD/$SOURCE/${SUNXI_TOOLS}/.git/packed-refs | grep refs/remotes/origin/master | cut -b1-7)-${ARCH}-${PKG_BUILD}${PACKAGER}.txz \
    >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    [[ -d $CWD/$BUILD/$PKG/${SUNXI_TOOLS} ]] && rm -rf $CWD/$BUILD/$PKG/${SUNXI_TOOLS}
}


build_flash_script() {
    message "" "create" "flash script"
    install -Dm755 "$CWD/blobs/${BOARD_NAME}/flash.sh" "$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    sed -e "s/\(\${ROOTFS}\)/$ROOTFS/g" \
        -e "s/\(\${ROOTFS_XFCE}\)/$ROOTFS_XFCE/g" \
        -e "s/\(\$TOOLS\)/$TOOLS/g" \
    -i "$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


create_bootloader_pack(){
    message "" "create" "bootloader pack"
    cd $CWD/$BUILD/$OUTPUT/ || exit 1
    install -Dm644 "$CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR/$BOOT_LOADER_BIN" "$CWD/$BUILD/$OUTPUT/boot/$BOOT_LOADER_BIN" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    [[ ! -z $BLOB_LOADER ]] && install -Dm644 "$CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$BLOB_LOADER" "$CWD/$BUILD/$OUTPUT/boot/$BLOB_LOADER" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    if [[ $SOCFAMILY == rk33* ]]; then
        install -Dm644 "$CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR/uboot.img" "$CWD/$BUILD/$OUTPUT/boot/uboot.img" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    [[ ! -z $ATF ]] && ( install -Dm644 "$CWD/$BUILD/$SOURCE/$ATF_SOURCE/trust.img" "$CWD/$BUILD/$OUTPUT/boot/trust.img" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    tar cJf $CWD/$BUILD/$OUTPUT/$FLASH/boot-${ROOTFS_VERSION}.tar.xz boot || exit 1
    for boot_file in $(ls $CWD/$BUILD/$OUTPUT/boot/ | grep -v $BLOB_LOADER); do
        cp -a "$CWD/$BUILD/$OUTPUT/boot/$boot_file" "$CWD/$BUILD/$SOURCE/$ROOTFS/boot/$boot_file" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    done
}


create_tools_pack(){
    message "" "create" "tools pack"
    cd $CWD/$BUILD/$OUTPUT/ || exit 1
    tar cJf $CWD/$BUILD/$OUTPUT/$FLASH/$TOOLS-$(uname -m).tar.xz $TOOLS || exit 1
}
