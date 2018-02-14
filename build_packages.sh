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
        cp -a $CWD/bin/$FIRMWARE/* -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    # install kernel
    install -Dm644 $CWD/$BUILD/$SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/$KERNEL "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/$KERNEL"

    # adding custom firmware
#    unzip -o $CWD/bin/$BOARD_NAME/$FIRMWARE -d $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#    cp -a $CWD/$BUILD/$SOURCE/hwpacks-master/system/etc/firmware $CWD/$BUILD/$PKG/kernel-modules/lib/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    [[ ! -z $FIRMWARE ]] && ( cp -a $CWD/bin/$FIRMWARE/* -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    touch "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/.next"

    # add device tree
    [[ ! -z $DEVICE_TREE_BLOB && $ARCH == arm ]] && ( install -Dm644 $CWD/$BUILD/$SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/$DEVICE_TREE_BLOB \
                                                        "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/$DEVICE_TREE_BLOB" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    [[ $SOCFAMILY == rk33* ]] && ( install -Dm644 $CWD/$BUILD/$SOURCE/$KERNEL_DIR/arch/${KARCH}/boot/dts/rockchip/$DEVICE_TREE_BLOB \
                                    "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/$DEVICE_TREE_BLOB" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    # u-boot
    [[ $SOCFAMILY == rk3* ]] && install -Dm644 $CWD/config/boot_scripts/boot-$SOCFAMILY.cmd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"

    if [[ $SOCFAMILY == sun* ]]; then

        # u-boot
        install -Dm644 $CWD/config/boot_scripts/boot-sunxi.cmd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"

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

            install -dm755 "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/"
            cat > "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/doinst.sh" << EOF
rm boot/.next 2> /dev/null
EOF
        fi
    fi

    # compile boot script
    [[ -f $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd ]] && ( $CWD/$BUILD/$SOURCE/$BOOT_LOADER/tools/mkimage -C none -A arm -T script -d $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd \
                                                                        "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.scr" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

    # u-boot
    [[ -f "$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" ]] && install -Dm644 "$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/$BOOT_LOADER_BIN"
    [[ -f "$CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt" ]] && install -Dm644 $CWD/config/boot_scripts/uEnv-$SOCFAMILY.txt "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/uEnv.txt"
    # change root disk if disk not default
    [[ -n ${ROOT_DISK##*mmcblk0p1} ]] && echo "rootdev=/dev/$ROOT_DISK" >> "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/uEnv.txt"

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

    cd $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    cd $CWD/$BUILD/$PKG/kernel-modules/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-modules-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    cd $CWD/$BUILD/$PKG/kernel-headers/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-headers-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    cd $CWD/$BUILD/$PKG/kernel-firmware/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-firmware-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${PKG_BUILD}${PACKAGER}.txz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    cd $CWD/$BUILD/$PKG

    # clear kernel packages directories
    if [ -d "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}" ]; then
        rm -rf "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    if [ -d "$CWD/$BUILD/$PKG/kernel-modules" ]; then
        rm -rf "$CWD/$BUILD/$PKG/kernel-modules" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    if [ -d "$CWD/$BUILD/$PKG/kernel-headers" ]; then
        rm -rf "$CWD/$BUILD/$PKG/kernel-headers" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    if [ -d "$CWD/$BUILD/$PKG/kernel-firmware" ]; then
        rm -rf "$CWD/$BUILD/$PKG/kernel-firmware" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


build_sunxi_tools() {
    message "" "build" "package ${SUNXI_TOOLS}"
    mkdir -p $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/{sbin,install}

    cat <<EOF >"$CWD/$BUILD/$PKG/${SUNXI_TOOLS}/install/slack-desc"
# HOW TO EDIT THIS FILE:
# The "handy ruler" below makes it easier to edit a package description.  Line
# up the first '|' above the ':' following the base package name, and the '|'
# on the right side marks the last column you can put a character in.  You must
# make exactly 11 lines for the formatting to be correct.  It's also
# customary to leave one space after the ':'.

           |-----handy-ruler------------------------------------------------------|
sunxi-tools: sunxi-tools
sunxi-tools:
sunxi-tools: Tools to help hacking Allwinner A10 (aka sun4i) based devicesand possibly
sunxi-tools: and possibly it's successors, that's why the 'x' in the package name.
sunxi-tools:
sunxi-tools:
sunxi-tools: Homepage:  https://github.com/linux-sunxi/sunxi-tools
sunxi-tools:
sunxi-tools:
sunxi-tools:
sunxi-tools:
EOF

    cp -P $CWD/$BUILD/$SOURCE/${SUNXI_TOOLS}/{bin2fex,fex2bin,sunxi-fexc,sunxi-nand-part} \
          $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/sbin/

    cd $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/
    makepkg -l n -c n $CWD/$BUILD/$PKG/${SUNXI_TOOLS}-git_$(date +%Y%m%d)_$(cat $CWD/$BUILD/$SOURCE/${SUNXI_TOOLS}/.git/packed-refs | grep refs/remotes/origin/master | cut -b1-7)-${ARCH}-${PKG_BUILD}${PACKAGER}.txz \
    >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    if [ -d $CWD/$BUILD/$PKG/${SUNXI_TOOLS} ];then
        rm -rf $CWD/$BUILD/$PKG/${SUNXI_TOOLS}
    fi
}


add_linux_upgrade_tool() {
    message "" "add" "$LINUX_UPGRADE_TOOL"
    unzip -o $CWD/bin/rockchip/$LINUX_UPGRADE_TOOL.zip -d $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    # add tool for flash boot loader
    cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/upgrade_tool $CWD/$BUILD/$OUTPUT/$TOOLS/
    cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/config.ini $CWD/$BUILD/$OUTPUT/$TOOLS/
}


build_flash_script() {
    message "" "create" "flash script"
    install -Dm755 "$CWD/bin/${BOARD_NAME}/flash.sh" "$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    sed -e "s/\(\${ROOTFS}\)/$ROOTFS/g" \
        -e "s/\(\${ROOTFS_XFCE}\)/$ROOTFS_XFCE/g" \
        -e "s/\(\$TOOLS\)/$TOOLS/g" \
    -i "$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


create_bootloader_pack(){
    message "" "create" "bootloader pack"
    cd $CWD/$BUILD/$OUTPUT/ || exit 1
    create_uboot 'mmc'
    install -Dm644 "$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" "$CWD/$BUILD/$OUTPUT/boot/$BOOT_LOADER_BIN" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    install -Dm644 "$CWD/$BUILD/$SOURCE/$RKBIN/${SOCFAMILY:0:4}/$BLOB_LOADER" "$CWD/$BUILD/$OUTPUT/boot/$BLOB_LOADER" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    install -Dm644 "$CWD/$BUILD/$SOURCE/$BOOT_LOADER/uboot.img" "$CWD/$BUILD/$OUTPUT/boot/uboot.img" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    [[ ! -z $ATF ]] && install -Dm644 "$CWD/$BUILD/$SOURCE/$ATF_SOURCE/trust.img" "$CWD/$BUILD/$OUTPUT/boot/trust.img" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    tar cJf $CWD/$BUILD/$OUTPUT/$FLASH/boot.tar.xz boot || exit 1
}


create_tools_pack(){
    message "" "create" "tools pack"
    cd $CWD/$BUILD/$OUTPUT/ || exit 1
    tar cJf $CWD/$BUILD/$OUTPUT/$FLASH/$TOOLS-$(uname -m).tar.xz $TOOLS || exit 1
}
