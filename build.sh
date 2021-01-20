#!/bin/bash



#---------------------------------------------
# environment
#---------------------------------------------
set -e
CWD=$(pwd)

[[ $EUID != 0 ]] && echo -e "\nThis script must be run with root privileges\n" && exit 1

TTY_X=$(($(stty size | cut -f2 -d " ")-10)) # determine terminal width
TTY_Y=$(($(stty size | cut -f1 -d " ")-10)) # determine terminal height


#---------------------------------------------
# get boards
#---------------------------------------------
for board in $CWD/config/boards/*/*.conf ;do
    BOARDS+=( $(echo $board | rev | cut -d '/' -f1 | cut -d '.' -f2 | rev) "$(sed -n '/^#/{3p}' $board | sed 's:#\s::')" "off")
done

if [[ -z $BOARD_NAME ]]; then
    # no menu
    NO_MENU=yes

    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    while true; do
        BOARD_NAME=$(dialog --title "build rootfs" \
                    --radiolist "selected your board" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                    "${BOARDS[@]}" \
        2>&1 1>&3)

        [ ! -e $BOARD_NAME ] && break
    done
    # Close file descriptor 3
    exec 3>&-
fi


#---------------------------------------------
# get kernel source type
#---------------------------------------------
if [[ $NO_MENU == yes ]]; then
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    KERNEL_SOURCES=$(grep -oP "(?<=_SOURCES=).*$" $CWD/config/boards/$BOARD_NAME/${BOARD_NAME}.conf | sed 's:\"::g')
    [ ! -z ${KERNEL_SOURCES%%:*} ] && kernel_sources_options+=("${KERNEL_SOURCES%%:*}" "legacy kernel source" "off")
    [ ! -z ${KERNEL_SOURCES##*:} ] && kernel_sources_options+=("${KERNEL_SOURCES##*:}" "mainline kernel source" "off")
    while true; do
        # kernel source
        KERNEL_SOURCE=$(dialog --title "build for $BOARD_NAME" \
                --radiolist "select kernel source" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                "${kernel_sources_options[@]}" \
        2>&1 1>&3)

        [ ! -e $KERNEL_SOURCE ] && break
    done
    # Close file descriptor 3
    exec 3>&-
fi


DESKTOP=$(grep -oP "(?<=DESKTOP\=).*$" $CWD/config/boards/$BOARD_NAME/${BOARD_NAME}.conf || echo "no")
options+=("clean" "clean sources, remove binaries and image" "off")
options+=("download" "download source and use pre-built binaries" "on")
options+=("compile" "build binaries locally" "on")
options+=("tools" "create and pack tools" "on")
[[ $DESKTOP == yes ]] && options+=("desktop" "create image with xfce" "on")

if [[ $NO_MENU == yes ]]; then
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    while true; do
        result=$(dialog --title "build $KERNEL_SOURCE for $BOARD_NAME" \
               --checklist "select build options" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
               "${options[@]}" \
        2>&1 1>&3)
        [ ! -z "$result" ] && break
    done
    exit_status=$?
    # Close file descriptor 3
    exec 3>&-
    for arg in ${result[*]}; do
        case "$arg" in
            download)
                        DOWNLOAD_SOURCE_BINARIES=yes
                    ;;
               clean)
                        CLEAN=yes
                    ;;
             compile)
                        COMPILE_BINARIES=yes
                    ;;
               tools)
                        TOOLS_PACK=yes
                    ;;
             desktop)
                        DESKTOP_SELECTED=yes
                    ;;
        esac
    done
fi


#---------------------------------------------
# select build arch on x86_64
#---------------------------------------------
if [[ $(uname -m) == "x86_64" ]]; then
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
source $CWD/downloads.sh || exit 1
source $CWD/compilation.sh || exit 1
source $CWD/build_packages.sh || exit 1
source $CWD/build_images.sh || exit 1
source $CWD/configuration.sh || exit 1




#---------------------------------------------
# main script
#---------------------------------------------
if [[ $CLEAN == yes ]]; then
    clean_sources
fi

if [[ ! -e $BOARD_NAME ]]; then
    prepare_dest
fi

if [[ $DOWNLOAD_SOURCE_BINARIES == yes ]]; then
    download
fi
#---------------------------------------------
# start build
#---------------------------------------------
message "" "start" "build $DISTR ARCH $ARCH"
if [[ $COMPILE_BINARIES == yes ]]; then
    # aarch64 change interpreter path
    [[ $MARCH == aarch64 ]] && change_interpreter_path "${XTOOLS[@]}"
    clear_boot_tools
#    if [[ ! -z $ATF && $SOCFAMILY == rk33* ]] || [[ $SOCFAMILY == meson* ]]; then
    if [[ ! -z $ATF && $SOCFAMILY == rk33* ]]; then
        [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "u-boot-tools"
        compile_boot_tools
    fi
    [[ ! -z $ATF && $DOWNLOAD_SOURCE_BINARIES == yes ]] && ( patching_source "atf" && compile_atf )

    [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "u-boot"
    compile_boot_loader

    if [[ $DOWNLOAD_SOURCE_BINARIES == yes ]]; then
        external_patching_source
        patching_source "kernel"
    fi
    compile_kernel

    if [[ $SOCFAMILY == sun* && $TOOLS_PACK == yes ]]; then
        compile_sunxi_tools
        build_sunxi_tools
    fi

    build_kernel_pkg
fi

for image_type in ${DISTR_IMAGES[@]}; do

    get_name_rootfs $image_type
    clean_rootfs $image_type

    if [[ $image_type == base ]]; then
        prepare_rootfs
        create_bootloader_pack
        download_pkg $DISTR_URL "$image_type"
        install_pkg "$image_type"
        install_kernel
        create_initrd
        setting_system
        setting_bootloader
        setting_hostname
        setting_fstab
        setting_debug
        setting_motd
        setting_datetime
        setting_settings
        setting_wifi
        [[ $NTP == "yes" ]] && setting_ntp
        setting_bootloader_move_to_disk
        setting_governor
        create_img
        [[ $IMAGE_COMPRESSION == "yes" ]] && image_compression "$ROOTFS"
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

        [[ $NETWORKMANAGER == "yes" ]] && setting_networkmanager "$ROOTFS_XFCE"
        setting_default_start_x
        setting_for_desktop
        setting_alsa "$ROOTFS_XFCE"
        create_img "$image_type"
        [[ $IMAGE_COMPRESSION == "yes" ]] && image_compression "$ROOTFS_XFCE"
    fi
done



