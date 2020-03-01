#!/bin/bash



#---------------------------------------------
# environment
#---------------------------------------------
set -e
CWD=$(pwd)


TTY_X=$(($(stty size | cut -f2 -d " ")-10)) # determine terminal width
TTY_Y=$(($(stty size | cut -f1 -d " ")-10)) # determine terminal height


#---------------------------------------------
# get boards
#---------------------------------------------
for board in $CWD/config/boards/*/*.conf ;do
    BOARDS+=( $(echo $board | rev | cut -d '/' -f1 | cut -d '.' -f2 | rev) "$(sed -n '/^#/{3p}' $board | sed 's:#\s::')" "off")
done

# Duplicate file descriptor 1 on descriptor 3
exec 3>&1

while true; do
    BOARD_NAME=$(dialog --title "build rootfs" \
                --radiolist "selected your board" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                "${BOARDS[@]}" \
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

# Duplicate file descriptor 1 on descriptor 3
exec 3>&1

while true; do
    result=$(dialog --title "build $KERNEL_SOURCE for $BOARD_NAME" \
           --checklist "select build options" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
           "${options[@]}" \
    2>&1 1>&3)
    if [[ ! -z $result ]]; then break; fi
done

exit_status=$?
# Close file descriptor 3
exec 3>&-


for arg in ${result[*]}; do
    case "$arg" in
        download)
                    DOWNLOAD_SOURCE_BINARIES="true"
                ;;
           clean)
                    CLEAN="true"
                ;;
         compile)
                    COMPILE_BINARIES="true"
                ;;
           mini*)
                    DISTR_IMAGES+=($(echo $arg | cut -f1 -d '-'))
                ;;
           tools)
                    TOOLS_PACK="true"
                ;;
           xfce*)
                    DISTR_IMAGES+=($(echo $arg | cut -f1 -d '-'))
                ;;
    esac
done

#---------------------------------------------
# select build arch on x86_64
#---------------------------------------------
if [[ $MARCH == "x86_64" ]]; then
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    while true; do
        result=$(dialog --title "build $KERNEL_SOURCE for $BOARD_NAME" \
                --radiolist "select build architecture" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                "arm" "ARM-v7 32-bit architecture" "off" \
                "aarch64" "ARM-v8 64-bit architecture" "off" \
        2>&1 1>&3)
        if [[ ! -z $result ]]; then break; fi
    done

    exit_status=$?
    # Close file descriptor 3
    exec 3>&-

    for arg in $result; do
        if [ "$arg" == "arm" ]; then
                ARCH=$arg
        elif [ "$arg" == "aarch64" ]; then
                ARCH=$arg
        fi
    done
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
message "" "start" "build $DISTR ARCH $ARCH"
if [[ $COMPILE_BINARIES == true ]]; then
    clear_boot_tools
    [[ ! -z $ATF && $SOCFAMILY == rk33* ]] && compile_boot_tools
    [[ ! -z $ATF ]] && ( patching_source "atf" && compile_atf )

    patching_source "u-boot"
    compile_boot_loader

    patching_source "kernel"
    compile_kernel

    if [[ $SOCFAMILY == sun* && $TOOLS_PACK == true ]]; then
        compile_sunxi_tools
        build_sunxi_tools
    fi

    build_kernel_pkg
fi

for image_type in ${DISTR_IMAGES[@]}; do

    get_name_rootfs $image_type
    clean_rootfs $image_type

    if [[ $image_type == mini ]]; then
        download_rootfs
        prepare_rootfs
        create_bootloader_pack
        setting_hostname
        setting_fstab
        setting_debug
        setting_motd
        setting_issue
        setting_rc_local
        setting_firstboot
        setting_settings
        setting_sysctl
        setting_first_login
        setting_wifi
        setting_udev
        install_scripts
        setting_move_to_internal
        download_pkg $DISTR_URL "$image_type"
        install_pkg "$image_type"
        create_img
    fi

    if [[ $image_type == xfce ]]; then
        message "" "create" "$ROOTFS_XFCE"
        rsync -ar --del $SOURCE/$ROOTFS/ $SOURCE/$ROOTFS_XFCE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        download_pkg $DISTR_URL "$image_type"
        install_pkg "$image_type"

        # install extra packages
        download_pkg $DISTR_EXTRA_URL 'extra'
        install_pkg 'extra'

        # install extra board packages
        download_pkg $DISTR_EXTRA_URL $SOCFAMILY
        install_pkg $SOCFAMILY

        setting_default_theme_xfce
        setting_default_start_x
        setting_for_desktop
        setting_alsa "$ROOTFS_XFCE"
        create_img "$image_type"
    fi
done



