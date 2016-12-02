#!/bin/bash



#---------------------------------------------
# environment
#---------------------------------------------
set -e
CWD=$(pwd)


TTY_X=$(($(stty size | cut -f2 -d " ")-10)) # determine terminal width
TTY_Y=$(($(stty size | cut -f1 -d " ")-10)) # determine terminal height

# Duplicate file descriptor 1 on descriptor 3
exec 3>&1

while true; do
    BOARD_NAME=$(dialog --title "build rootfs" \
           --radiolist "selected your board" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
    "cubietruck" "Allwinner Tech SoC A20 ARM® Cortex™-A7" "off" \
    "firefly" "Rockchip RK3288 Cortex-A17 quad core@ 1.8GHz" "off" \
    "orange_pi_plus_2e" "Allwinner Tech SoC H3 ARM® Cortex™-A7" "off" \
    2>&1 1>&3)

    if [ ! -e $BOARD_NAME ]; then
        break
    fi
done

# kernel source
result=$(dialog --title "build for $BOARD_NAME" \
       --radiolist "select kernel source" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
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

options+=("clean" "clean sources, remove binaries and image" "off")
options+=("download" "download source and use pre-built binaries" "on")
options+=("compile" "build binaries locally" "on")
options+=("mini-image" "create basic image" "on")
options+=("tools" "create and pack tools" "on")
options+=("xfce-image" "create image with xfce" "off")

case $BOARD_NAME in
    cubietruck)
                options+=("hdmi" "video mode hdmi (defaul vga)" "off")
            ;;
    orange_pi_plus_2e)
                options+=("hdmi-to-dvi" "video mode via hdmi-to-dvi adapter" "off")
            ;;
esac

# Duplicate file descriptor 1 on descriptor 3
exec 3>&1

while true; do
    result=$(dialog --title "build for $BOARD_NAME" \
           --checklist "select build options" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
           "${options[@]}" \
    2>&1 1>&3)
    if [[ ! -z $result ]]; then break; fi
done

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
            CREATE_IMAGE=($(echo $arg | cut -f1 -d '-'))
    elif [ "$arg" == "tools" ]; then
            TOOLS_PACK="true"
    elif [ "$arg" == "xfce-image" ]; then
            CREATE_IMAGE+=($(echo $arg | cut -f1 -d '-'))
    elif [ "$arg" == "hdmi" ]; then
            VIDEO_OUTPUT=$arg
    elif [ "$arg" == "hdmi-to-dvi" ]; then
            VIDEO_OUTPUT=$arg
    fi
done

# set default
if [[ -e $VIDEO_OUTPUT ]]; then
    VIDEO_OUTPUT="vga"
fi

#---------------------------------------------
# clean terminal
#---------------------------------------------
reset

#---------------------------------------------
# configuration
#---------------------------------------------
source $CWD/overall.sh || exit 1
source $CWD/configuration.sh || exit 1
source $CWD/downloads.sh || exit 1
source $CWD/compilation.sh || exit 1
source $CWD/build_packages.sh || exit 1
source $CWD/build_slackware_rootfs.sh || exit 1




#---------------------------------------------
# clear log
#---------------------------------------------
if [[ -f $CWD/$BUILD/$SOURCE/$LOG ]]; then
    rm $CWD/$BUILD/$SOURCE/$LOG
fi

#---------------------------------------------
# main script
#---------------------------------------------
if [[ $CLEAN == true ]]; then
    clean_sources
fi

if [[ ! -e $BOARD_NAME ]]; then
    prepare_dest
fi

if [[ $DOWNLOAD_SOURCE_BINARIES == true ]]; then
    download
fi

#---------------------------------------------
# start build
#---------------------------------------------
if [[ $COMPILE_BINARIES == true ]]; then
        patching_source "u-boot"
        compile_boot_loader
        patching_source "kernel"
        compile_kernel

    if [[ $SOCFAMILY == rk3288 ]]; then
        compile_rk2918
        compile_rkflashtool
        compile_mkbooting
        add_linux_upgrade_tool
        create_bootloader_pack
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        compile_sunxi_tools
        build_sunxi_tools
    fi

    build_kernel_pkg
fi

for image_type in ${CREATE_IMAGE[@]}; do

    get_name_rootfs $image_type
    clean_rootfs $image_type

    if [[ $image_type == mini ]]; then
        download_rootfs
        prepare_rootfs
        setting_fstab
        setting_debug
        setting_motd
        setting_issue
        setting_rc_local
        setting_dhcpcd
        setting_firstboot
        setting_settings
        setting_first_login
        setting_wifi
#        if [[ $KERNEL_SOURCE != "next" && $SOCFAMILY == rk3288 ]]; then
#            setting_move_to_nand
#        fi
        setting_move_to_internal
        download_pkg $URL_DISTR "$image_type" ${CATEGORY_PKG[@]}
        install_pkg "$image_type" ${CATEGORY_PKG[@]}
        create_img
    fi

    if [[ $image_type == xfce ]]; then
        message "" "create" "$ROOTFS_XFCE"
        rsync -ar --del $CWD/$BUILD/$SOURCE/$ROOTFS/ $CWD/$BUILD/$SOURCE/$ROOTFS_XFCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        download_pkg $URL_DISTR "$image_type" ${CATEGORY_PKG[@]}
        install_pkg "$image_type" ${CATEGORY_PKG[@]}

        # install extra packages
        download_pkg $URL_DISTR_EXTRA 'extra' ${CATEGORY_PKG[@]}
        install_pkg 'extra' ${CATEGORY_PKG[@]}

        setting_default_theme_xfce
        setting_default_start_x
        setting_for_desktop
        setting_alsa "$ROOTFS_XFCE"
        create_img xfce
    fi
done

if [[ $TOOLS_PACK == true && $SOCFAMILY == rk3288 ]]; then
    build_flash_script
    create_tools_pack
fi



