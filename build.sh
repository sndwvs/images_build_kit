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
# board configuration
#---------------------------------------------
source $CWD/overall.sh || exit 1

#---------------------------------------------
# set global architecture
#---------------------------------------------
set_architecture

#---------------------------------------------
# get boards
#---------------------------------------------
for board in $CWD/config/boards/*/*.conf ;do
    if [[ $(grep -oP "(?<=DISTRIBUTION_ARCHITECTURE=[\"\']).*(?=[\'\"]$)" $board) =~ $ARCH ]]; then
        BOARDS+=( $(echo $board | rev | cut -d '/' -f1 | cut -d '.' -f2 | rev) "$(sed -n '/^#/{3p}' $board | sed 's:#\s::')" "off")
    fi
done

if [[ -z $BOARD_NAME ]]; then
    # no menu
    NO_MENU=yes

    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    while true; do
        BOARD_NAME=$(dialog --title " build a distribution image of $ARCH architecture " \
                    --radiolist "selected your board" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                    "${BOARDS[@]}" \
        2>&1 1>&3)

        [ ! -e $BOARD_NAME ] && break
    done
    # Close file descriptor 3
    exec 3>&-
fi

#---------------------------------------------
# get linux distributions
#---------------------------------------------
for _distr in $(grep -oP "(?<=DISTRS=[\"\']).*(?=[\'\"]$)" $CWD/config/environment/environment.conf); do
    _selected="off"
    _distribution_architecture=$(grep -oP "(?<=DISTRIBUTION_ARCHITECTURE=[\"\']).*(?=[\'\"]$)" $CWD/config/boards/${BOARD_NAME}/${BOARD_NAME}.conf)
    if [[ ${_distr} == slarm64 && ${_distribution_architecture} =~ (aarch|riscv)64 ]]; then
        DISTRS+=(${_distr} "linux" ${_selected})
    elif [[ ${_distr} == slackwarearm* && ${_distribution_architecture} =~ arm ]]; then
        DISTRS+=(${_distr} "linux" ${_selected})
    elif [[ ${_distr} == crux* && ${_distribution_architecture} =~ (arm|aarch64) ]]; then
        DISTRS+=(${_distr} "linux" ${_selected})
    fi
done
if [[ -z $DISTR ]]; then
    # no menu
    NO_MENU=yes

    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    while true; do
        DISTR=$(dialog --title " build for board ${BOARD_NAME/_/-} " \
                    --radiolist "select distribution" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                    "${DISTRS[@]}" \
        2>&1 1>&3)

        [ ! -e $DISTR ] && break
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
        KERNEL_SOURCE=$(dialog --title " build kernel for ${BOARD_NAME/_/-} " \
                --radiolist "select kernel source" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                "${kernel_sources_options[@]}" \
        2>&1 1>&3)

        [ ! -e $KERNEL_SOURCE ] && break
    done
    # Close file descriptor 3
    exec 3>&-
fi


DESKTOP=$(grep -oP "(?<=DESKTOP\=).*$" $CWD/config/boards/$BOARD_NAME/${BOARD_NAME}.conf || echo "no")
DISTR_IMAGES=$(grep -oP "(?<=DISTR_IMAGES=).*(?=$)" $CWD/config/environment/environment.conf)
options+=("clean" "clean sources, remove binaries and image" "off")
options+=("download" "download source and use pre-built binaries" "on")
options+=("compile" "build binaries locally" "on")
options+=($DISTR_IMAGES "create default image" "on")
[[ $DESKTOP == yes && $DISTR != crux* ]] && options+=("desktop" "create an image with a desktop (optional)" "on")
unset DISTR_IMAGES

if [[ $NO_MENU == yes ]]; then
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    while true; do
        result=$(dialog --title " build $KERNEL_SOURCE for ${BOARD_NAME/_/-} " \
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
             desktop)
                        DESKTOP_SELECTED=yes
                    ;;
             server)
                        DISTR_IMAGES="server"
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
        result=$(dialog --title " build $KERNEL_SOURCE for ${BOARD_NAME/_/-} " \
                --radiolist "select build architecture" $TTY_Y $TTY_X $(($TTY_Y - 8)) \
                "arm" "ARM-v7 32-bit architecture" "off" \
                "aarch64" "ARM-v8 64-bit architecture" "off" \
                "riscv64" "RISC-V 64-bit architecture" "off" \
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
        elif [ "$arg" == "riscv64" ]; then
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
message "" "start" "build $DISTR ARCH $ARCH images: ${DISTR_IMAGES[*]}"
if [[ $COMPILE_BINARIES == yes ]]; then
    # aarch64 change interpreter path
    [[ $MARCH == aarch64 ]] && change_interpreter_path "${XTOOLS[@]}"
    clear_boot_tools
#    if [[ ! -z $ATF && $SOCFAMILY == rk33* ]] || [[ $SOCFAMILY == meson* ]]; then
    if [[ ! -z $ATF && $SOCFAMILY == rk33* ]]; then
        [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "u-boot-tools"
        compile_boot_tools
    fi

    [[ ! -z $BOOT_PACKER_LOADER_DIR ]] && compile_boot_packer_loader

    if [[ ! -z $ATF ]]; then
        [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "atf"
        compile_atf
    fi

    if [[ ! -z $DDRINIT_DIR ]]; then
        [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "ddrinit"
        compile_ddrinit
    fi

    if [[ ! -z $SECOND_BOOT_DIR ]]; then
        [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "second-boot"
        compile_second_boot
    fi

    if [[ ! -z $OPENSBI ]]; then
        [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "opensbi"
        compile_opensbi
    fi

    [[ $DOWNLOAD_SOURCE_BINARIES == yes ]] && patching_source "u-boot"
    compile_boot_loader

    if [[ $DOWNLOAD_SOURCE_BINARIES == yes ]]; then
        external_patching_source
        patching_source "kernel"
    fi
    compile_kernel

    build_kernel_pkg
fi

for image_type in ${DISTR_IMAGES[@]}; do

    get_name_rootfs ${image_type}
    clean_rootfs ${image_type}

    if [[ ${image_type} =~ server|core || ( $DESKTOP_SELECTED == yes && ! ${DISTR_IMAGES[@]} =~ server|core ) ]]; then
        prepare_rootfs
        create_archive_bootloader
        download_pkg $DISTR_URL "${image_type}"
        install_pkg "${image_type}"
        if [[ ${DISTR} == crux* ]]; then
            download_pkg "${DISTR_URL}-update" "${image_type}-update"
            install_pkg "${image_type}-update"
            download_pkg "${DISTR_URL}" "opt"
            install_pkg "opt"
        fi
        install_kernel
        setting_system
        setting_bootloader
        setting_overlays
        setting_hostname
        setting_fstab
        setting_debug
        setting_motd
        setting_datetime
        setting_ssh
        setting_dhcp
        create_initrd
        if [[ ${DISTR} != crux* ]]; then
            setting_wifi
            setting_governor
        fi
        [[ $NTP == yes ]] && setting_ntp
        setting_modules
        setting_bootloader_move_to_disk
        create_img "$ROOTFS"
        build_img "$ROOTFS"
        [[ $IMAGE_COMPRESSION == yes ]] && image_compression "$ROOTFS"
    fi

    if [[ ! ${image_type} =~ server|core || ( $DESKTOP_SELECTED == yes && ${#DISTR_IMAGES[@]} == 1 ) ]]; then
        message "" "create" "$ROOTFS_DESKTOP"
        mv $SOURCE/$ROOTFS $SOURCE/$ROOTFS_DESKTOP >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        # installing overall distribution desktop packages
        download_pkg $DISTR_URL "desktop"
        install_pkg "desktop"

        # installing distribution desktop packages
        download_pkg $DISTR_URL "desktop-${image_type}"
        install_pkg "desktop-${image_type}"

        # installing extra desktop packages
        download_pkg $DISTR_EXTRA_URL "desktop-${image_type}-extra"
        install_pkg "desktop-${image_type}-extra"

        # installing extra board packages
        download_pkg $DISTR_EXTRA_URL $SOCFAMILY
        install_pkg $SOCFAMILY

        [[ $NETWORKMANAGER == yes ]] && setting_networkmanager "$ROOTFS_DESKTOP"
        setting_default_start_x ${image_type}
        setting_for_desktop
        setting_alsa "$ROOTFS_DESKTOP"
        removed_default_xorg_conf "$ROOTFS_DESKTOP"
        create_img "$ROOTFS_DESKTOP"
        build_img "$ROOTFS_DESKTOP"
        [[ $IMAGE_COMPRESSION == yes ]] && image_compression "$ROOTFS_DESKTOP"
    fi
done



