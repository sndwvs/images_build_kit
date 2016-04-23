#!/bin/bash



#---------------------------------------------
# environment
#---------------------------------------------
set -e
CWD=$(pwd)



# Duplicate file descriptor 1 on descriptor 3
exec 3>&1

while true; do
    BOARD_NAME=$(dialog --title "build rootfs" \
           --radiolist "selected your board" 21 76 10 \
    "cubietruck" "Allwinner Tech SOC A20 ARM® Cortex™-A7" "off" \
    "firefly" "Rockchip RK3288 Cortex-A17 quad core@ 1.8GHz" "off" \
    2>&1 1>&3)

    if [ ! -e $BOARD_NAME ]; then
        break
    fi
done

# kernel source
result=$(dialog --title "build for $BOARD_NAME" \
       --radiolist "select kernel source" 21 76 10 \
"legacy" "legacy kernel-source" "off" \
"next" "mainline kernel-source" "on" \
2>&1 1>&3)

exit_status=$?
# Close file descriptor 3
exec 3>&-

for arg in $result; do
    if [ "$arg" == "legacy" ]; then
            KERNEL_SOURCE=$arg
    elif [ "$arg" == "next" ]; then
            KERNEL_SOURCE=$arg
    fi
done


# Duplicate file descriptor 1 on descriptor 3
exec 3>&1
       
result=$(dialog --title "build for $BOARD_NAME" \
       --checklist "select build options" 21 76 10 \
"clean" "clean sources, remove binaries and image" "off" \
"download" "download source and use pre-built binaries" "on" \
"compile" "build binaries locally" "on" \
"mini-image" "create basic image" "on" \
"tools" "create and pack tools" "on" \
"xfce-image" "create image with xfce" "off" \
"hdmi" "video mode hdmi (defaul vga)" "off" \
2>&1 1>&3)

exit_status=$?
# Close file descriptor 3
exec 3>&-

for arg in $result; do
    if [ "$arg" == "download" ]; then
            DOWNLOAD_SOURCE_BINARIES="true"
    elif [ "$arg" == "clean" ]; then
            CLEAN="true"
    elif [ "$arg" == "compile" ]; then
            COMPILE_BINARIES="true"
    elif [ "$arg" == "mini-image" ]; then
            CREATE_IMAGE="true"
    elif [ "$arg" == "tools" ]; then
            TOOLS_PACK="true"
    elif [ "$arg" == "xfce-image" ]; then
            XFCE="true"
    elif [ "$arg" == "hdmi" ]; then
            HDMI=$arg
    fi   
done




#---------------------------------------------
# configuration
#---------------------------------------------
source $CWD/overall.sh || exit 1
source $CWD/configuration.sh || exit 1
source $CWD/downloads.sh || exit 1
source $CWD/compilation.sh || exit 1
source $CWD/build_slackware_rootfs.sh || exit 1




#---------------------------------------------
# clear log
#---------------------------------------------
if [[ -f $CWD/$BUILD/$SOURCE/$LOG ]];then
    rm $CWD/$BUILD/$SOURCE/$LOG
fi

#---------------------------------------------
# main script
#---------------------------------------------

if [ ! -z "$KERNEL_VERSION" ]; then
    message "" "build" "rootfs for kernel version $KERNEL_VERSION"
fi

if [ "$CLEAN" == "true" ]; then
    clean_sources
fi

if [ ! -e "$BOARD_NAME" ]; then
    prepare_dest
fi

if [ "$DOWNLOAD_SOURCE_BINARIES" == "true" ]; then
    download
fi

if [ "$COMPILE_BINARIES" == "true" ]; then
    if [ "$BOARD_NAME" == "firefly" ]; then
        compile_rk2918
        compile_rkflashtool
        compile_mkbooting
        add_linux_upgrade_tool
        compile_boot_loader
        patching_kernel_sources
        compile_kernel
        build_parameters
        if [ "$KERNEL_SOURCE" == "next" ]; then
            build_kernel
        else
            build_resource
        fi
        build_boot
    fi

    if [ "$BOARD_NAME" == "cubietruck" ]; then
        patching_kernel_sources
        compile_sunxi_tools
        build_sunxi_tools
        compile_boot_loader
        compile_kernel
    fi

    build_kernel_pkg
fi

if [[ "$TOOLS_PACK" == "true" && "$BOARD_NAME" == "firefly" ]]; then
    build_flash_script
    create_tools_pack
fi

if [ "$CREATE_IMAGE" == "true" ]; then
    clean_rootfs
    download_rootfs
    prepare
    setting_fstab
    setting_debug
    setting_motd
    setting_rc_local
    setting_dhcpcd
    setting_firstboot
    setting_settings
    if [[ "$KERNEL_SOURCE" != "next" && "$BOARD_NAME" == "firefly" ]]; then
        setting_wifi
    fi
    if [ "$XFCE" == "true" ]; then
        message "" "create" "$ROOTFS_XFCE"
        cp -fr $CWD/$BUILD/$SOURCE/$ROOTFS/ $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
        download_pkg $URL_DISTR '' $CATEGORY_PKG
        if [ "$BOARD_NAME" == "firefly" ]; then
            download_pkg $URL_DISTR_EXTRA 'extra' $CATEGORY_PKG
            install_pkg 'extra' $CATEGORY_PKG
        fi
        install_pkg '' $CATEGORY_PKG
        setting_default_theme_xfce
        setting_default_start_x
#        if [ "$BOARD_NAME" == "firefly" ]; then
#            download_video_driver
#            build_video_driver_pkg
#            install_video_driver_pkg
#        fi
        create_img xfce
    fi
    create_img
fi



