#!/bin/bash



if [ -z $CWD ]; then
    exit
fi


build_kernel_pkg() {
    # get kernel version
    kernel_version KERNEL_VERSION

    if [[ $SOCFAMILY == rk3288 ]] && [[ ! -z $FIRMWARE ]]; then
        # add firmware
        unzip -o $CWD/bin/$BOARD_NAME/$FIRMWARE -d $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        cp -a $CWD/$BUILD/$SOURCE/hwpacks-master/system/etc/firmware $CWD/$BUILD/$PKG/kernel-modules/lib/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        # adding custom firmware
        unzip -o $CWD/$BUILD/$SOURCE/$FIRMWARE -d $CWD/$BUILD/$PKG/kernel-modules/lib/firmware >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        install -Dm644 $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/${ARCH}/boot/zImage "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/zImage"

        install -Dm644 $CWD/config/boot.cmd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"

        touch "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/.verbose"

        $CWD/$BUILD/$SOURCE/$BOOT_LOADER/tools/mkimage -C none -A arm -T script -d $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.scr" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm644 "$CWD/$BUILD/$SOURCE/$BOOT_LOADER/$BOOT_LOADER_BIN" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/$BOOT_LOADER_BIN"

        if [[ $KERNEL_SOURCE == next ]];then
                install -Dm644 $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/arch/${ARCH}/boot/dts/$DEVICE_TREE_BLOB "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/dtb/$DEVICE_TREE_BLOB" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
                touch "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/.next"
        else

            install -Dm644 "$CWD/config/boards/$BOARD_NAME/script-hdmi.bin" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-hdmi.bin"
            install -Dm644 "$CWD/config/boards/$BOARD_NAME/script-vga.bin" "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/script-vga.bin"

            cd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/"
            if [ -e $HDMI ];then
                ln -sf "script-vga.bin" "script.bin"
            else
                ln -sf "script-hdmi.bin" "script.bin"
            fi
            cd "$CWD"

            install -dm755 "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/"
            cat > "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/install/doinst.sh" << EOF
rm boot/.next 2> /dev/null
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
    cd $CWD/$BUILD/$PKG/kernel-modules/lib/modules/${KERNEL_VERSION}*
    rm build source
    ln -s /usr/include build
    ln -s /usr/include source

    if [ "$BOARD_NAME" == "cubietruck" ]; then
        cd $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/
        makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${_BUILD}${PACKAGER}.txz
    fi

    cd $CWD/$BUILD/$PKG/kernel-modules/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-modules-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${_BUILD}${PACKAGER}.txz

    cd $CWD/$BUILD/$PKG/kernel-headers/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-headers-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${_BUILD}${PACKAGER}.txz

    cd $CWD/$BUILD/$PKG/kernel-firmware/
    makepkg -l n -c n $CWD/$BUILD/$PKG/kernel-firmware-${SOCFAMILY}-${KERNEL_VERSION}-${ARCH}-${_BUILD}${PACKAGER}.txz

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

    find "$CWD/$BUILD/$SOURCE/${SUNXI_TOOLS}" \( -name bin2fex -o -name fex2bin -o -name fexc -o -name nand-part \) \
         -exec cp -P {} $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/sbin/. \;

    cd $CWD/$BUILD/$PKG/${SUNXI_TOOLS}/
    makepkg -l n -c n $CWD/$BUILD/$PKG/${SUNXI_TOOLS}-git_$(date +%Y%m%d)_$(cat $CWD/$BUILD/$SOURCE/${SUNXI_TOOLS}/.git/packed-refs | grep refs/remotes/origin/master | cut -b1-7)-${ARCH}-${_BUILD}${PACKAGER}.txz

    if [ -d $CWD/$BUILD/$PKG/${SUNXI_TOOLS} ];then
        rm -rf $CWD/$BUILD/$PKG/${SUNXI_TOOLS}
    fi
}


add_linux_upgrade_tool() {
    message "" "add" "$LINUX_UPGRADE_TOOL"
    # add tool for flash boot loader
    cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/upgrade_tool $CWD/$BUILD/$OUTPUT/$TOOLS/
    cp -a $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL/config.ini $CWD/$BUILD/$OUTPUT/$TOOLS/
}


build_parameters() {
    message "" "create" "parameters"
    # add parameters for flash
    install -m644 -D "$CWD/config/boards/$BOARD_NAME/parameters.txt" "$CWD/$BUILD/$OUTPUT/$FLASH/parameters.txt"
    sed -i "s#mmcblk[0-9]p[0-9]#$ROOT_DISK#" "$CWD/$BUILD/$OUTPUT/$FLASH/parameters.txt"
}


build_flash_script() {
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
    if [ "$KERNEL_SOURCE" == "next" ]; then
        sed -i 's#resource#kernel#g' "$CWD/$BUILD/$OUTPUT/$FLASH/flash.sh"
    fi
}


create_tools_pack(){
    message "" "create" "tools pack"
    cd $CWD/$BUILD/$OUTPUT/ || exit 1
    tar cJf $CWD/$BUILD/$OUTPUT/$FLASH/$TOOLS-$(uname -m).tar.xz $TOOLS || exit 1
}
