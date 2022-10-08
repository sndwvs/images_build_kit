#!/bin/bash



if [ -z $CWD ];then
    exit
fi


#---------------------------------------------
# set MARCH - host, KARCH - kernel, ARCH - distribution architecture
#---------------------------------------------
set_architecture() {
    MARCH=$( uname -m )
    case "$MARCH" in
        armv7hl) export MARCH=$MARCH ;;
        arm*)    export MARCH=arm ;;
        *)       export MARCH=$MARCH ;;
    esac

    [[ -z $ARCH ]] && export ARCH=${ARCH:-$MARCH}

    if [[ $ARCH == arm* ]]; then
        KARCH=${KARCH:-$ARCH}
    elif [[ $ARCH == aarch64 ]]; then
        KARCH="arm64"
    elif [[ $ARCH == riscv64 ]]; then
        KARCH="riscv"
    fi
    export KARCH
}

#---------------------------------------------
# display message
#---------------------------------------------
message() {
    # parametr 1 - type message
    #     "err"  - error
    #     "warn" - warning
    #     "info" - info (default is empty)
    # parametr 2 - action message
    # parametr 3 - text message

    if [[ ! -z "$2" ]]; then ACTION="$2"; else unset ACTION; fi
    if [[ ! -z "$3" ]]; then MESSAGE="$3"; else unset MESSAGE; fi

    if [[ "$1" == "err" ]]; then
        printf '|\e[1;31m%s \x1B[0m| \e[0;32m%-12s\x1B[0m %s\n' "$1" "$ACTION" "$LOG"
    elif [[ "$1" == "warn" ]]; then
        printf '|\e[1;33mwarn\x1B[0m| \e[0;32m%-12s\x1B[0m %s\n' "$ACTION" "$MESSAGE"
        [[ -f $LOG ]] && echo "|----------- delimiter ----------- \"$ACTION\" \"$MESSAGE\" -----------|" >> $LOG
    elif [[ "$1" == "info" || -z "$1" ]]; then
        printf '|\e[1;36minfo\x1B[0m| \e[0;32m%-12s\x1B[0m %s\n' "$ACTION" "$MESSAGE"
        [[ -f $LOG ]] && echo "|----------- delimiter ----------- \"$ACTION\" \"$MESSAGE\" -----------|" >> $LOG
    fi
    return 0
}

#---------------------------------------------
# get version from Makefile
#---------------------------------------------
get_version() {
    local VER=()

    if [[ ! -f "$1"/Makefile ]]; then
        echo "no get version" >> $LOG
        (message "err" "details" && exit 1) || exit 1
    fi

    VER[0]=$(cat "$1"/Makefile | grep VERSION | head -1 | cut -d ' ' -f3-)
    VER[1]=$(cat "$1"/Makefile | grep PATCHLEVEL | head -1 | cut -d ' ' -f3-)
    VER[2]=$(cat "$1"/Makefile | grep SUBLEVEL | head -1 | cut -d ' ' -f3-)
    VER[3]=$(cat "$1"/Makefile | grep EXTRAVERSION | head -1 | cut -d ' ' -f3-)
    echo ${VER[0]}${VER[1]+.${VER[1]}}${VER[2]:+.${VER[2]}}${VER[3]}
}

#---------------------------------------------
# get config
#---------------------------------------------
get_config() {
    local dirs=(    "$CWD/config/environment"
                    "$CWD/config/boards/$BOARD_NAME"
                    "$CWD/config/sources/$SOCFAMILY"
#                    "$CWD/config/packages"
                )

    # applied first
    message "" "added" "configuration file environment.conf"
    source "$CWD/config/environment/environment.conf" || exit 1

    for dir in "${dirs[@]}"; do
        for file in ${dir}/*.conf; do
            _file=$(basename ${file})
            if [[ $(echo "${dir}" | grep "environment") && "${_file}" != "environment.conf" ]]; then
                message "" "added" "configuration file $_file"
                source "$file" || exit 1
            fi
            if [[ -n ${BOARD_NAME} && ! ${_file%%${BOARD_NAME}*} ]]; then
                message "" "added" "configuration file $_file"
                source "$file" || exit 1
            fi
            if [[ -n ${SOCFAMILY} && ! ${_file%%${SOCFAMILY}*} ]]; then
                message "" "added" "configuration file $_file"
                source "$file" || exit 1
            fi
            #---- packages
#            for image_type in ${CREATE_IMAGE[@]}; do
#                if [[ $image_type == xfce ]]; then
#                    if [[ -n ${BOARD_NAME} && ! ${_file%%*-${BOARD_NAME}*} ]]; then
#                         message "" "added" "configuration file $_file"
#                         source "$file" || exit 1
#                    fi

#                    [[ $file == *extra* ]] && source "$file" && \
#                                            message "" "added" "configuration file $(basename $file)"

#                fi
#                if [[ ! ${_file%%*-${image_type}*} ]]; then
#                     message "" "added" "configuration file $_file"
#                     source "$file" || exit 1
#                fi
#            done
            #---- packages
        done
    done
}

#---------------------------------------------
# convert version to number
#---------------------------------------------
version() {
    local ver="$@"
    # for comparison, we take the numbers before the point and after
    # $1  : a version string of form 12.34.56 converts to 12034056
    # use: [[ $(version 1.2.3) >= $(version 1.2.3) ]] && echo "yes" || echo "no"
    #echo $ver | sed 's:^\([0-9]*\)\.\([0-9]*\).*:\1\2:g'
    echo "${ver[@]}" | gawk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }' | sed 's:^[0]*::g'
}

#---------------------------------------------
# patching process
#---------------------------------------------
patching_source() {

    local dirs
    local PATCH_SOURCE
    local names=()

    case "$1" in
        kernel)
                dirs=(      "$CWD/patch/kernel/$SOCFAMILY-$KERNEL_SOURCE"
                            "$CWD/patch/kernel/$SOCFAMILY-$KERNEL_SOURCE/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$KERNEL_DIR"
            ;;
        u-boot)
                dirs=(
                            "$CWD/patch/u-boot/$SOCFAMILY"
                            "$CWD/patch/u-boot/$SOCFAMILY/$KERNEL_SOURCE"
                            "$CWD/patch/u-boot/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$BOOT_LOADER_DIR"
            ;;
        u-boot-tools)
                dirs=(
                            "$CWD/patch/u-boot-tools/$SOCFAMILY"
                            "$CWD/patch/u-boot-tools/$SOCFAMILY/$KERNEL_SOURCE"
                            "$CWD/patch/u-boot-tools/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$BOOT_LOADER_TOOLS_DIR"
            ;;
        atf)
                dirs=(      "$CWD/patch/atf/$SOCFAMILY"
                            "$CWD/patch/atf/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$ATF_DIR"
            ;;
        opensbi)
                dirs=(      "$CWD/patch/opensbi/$SOCFAMILY"
                            "$CWD/patch/opensbi/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$OPENSBI_DIR"
            ;;
        second-boot)
                dirs=(      "$CWD/patch/second-boot/$SOCFAMILY"
                            "$CWD/patch/second-boot/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$SECOND_BOOT_DIR"
            ;;
        ddrinit)
                dirs=(      "$CWD/patch/ddrinit/$SOCFAMILY"
                            "$CWD/patch/ddrinit/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$DDRINIT_DIR"
            ;;
    esac


    # required for "for" command
    shopt -s nullglob dotglob
    for dir in "${dirs[@]}"; do
        for file in ${dir%%:*}/*.patch; do
            names+=($(basename $file)) || exit 1
        done
    done

    # remove duplicates
    local names_s=($(echo "${names[@]}" | sed 's/\s/\n/g' | LC_ALL=C sort -u | sed 's/\n/\s/g'))

    [[ -z $names_s ]] && return 0

    pushd $PATCH_SOURCE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    set +e

    for file in "${names_s[@]}"; do
        for dir in "${dirs[@]}"; do
            if [[ -f "${dir}/${file}" ]]; then
                # detect and remove files which patch will create
                LANGUAGE=english patch --batch --dry-run -p1 -N < "${dir}/${file}" | grep create \
                        | awk '{print $NF}' | sed -n 's/,$//p' | xargs -I % sh -c 'rm %'

                patch --batch --silent -Np1 < "${dir}/${file}" >> $LOG 2>&1

                if [[ $? -ne 0 ]]; then
                    message "warn" "patching" "not succeeded: $file"
#                    mv "${dir}/${file}" "${dir}/${file}.auto.disabled"
                else
                    message "" "patching" "succeeded: $file"
                fi
            fi
        done
    done

    set -e

    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

#---------------------------------------------
# external patching process
#---------------------------------------------
external_patching_source() {
    KERNEL_VERSION=$(get_version $SOURCE/$KERNEL_DIR)

    if [[ $EXTERNAL_WIREGUARD == yes && $(version $KERNEL_VERSION) -ge $(version 3.10) && $(version $KERNEL_VERSION) -le $(version 5.5) ]]; then
        local PREFFIX="net"
        SOURCES='https://git.zx2c4.com/wireguard-linux-compat|wireguard|master::'
        IFS='|'
        local source_array=($SOURCES)
        unset IFS
        local DRIVER_URL="${source_array[0]}"
        local DRIVER_NAME="${source_array[1]}"
        local DRIVER_BRANCH="${source_array[2]}"

        [[ -d $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME ]] && ( rm -rf $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME || (message "err" "details" && exit 1) || exit 1 )
        message "" "download" "external driver $DRIVER_NAME"
        # git_fetch <dir> <url> <branch>
        git_fetch $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME $DRIVER_URL $DRIVER_BRANCH
        mv $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/src/* $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/
        # clean .git, src
        [[ -d $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/.git ]] && ( rm -rf $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/{.git*,src} || (message "err" "details" && exit 1) || exit 1 )
        sed -i "/^obj-\\\$(CONFIG_NETFILTER).*+=/a obj-\$(CONFIG_WIREGUARD) += $DRIVER_NAME/" \
            $SOURCE/$KERNEL_DIR/${PREFFIX}/Makefile
        sed -i "/^if INET\$/a source \"net/wireguard/Kconfig\"" \
            $SOURCE/$KERNEL_DIR/${PREFFIX}/Kconfig
        # remove duplicates
        [[ $(grep -c $DRIVER_NAME $SOURCE/$KERNEL_DIR/${PREFFIX}/Makefile) -gt 1 ]] && \
        sed -i '0,/wireguard/{/wireguard/d;}' $SOURCE/$KERNEL_DIR/${PREFFIX}/Makefile
        [[ $(grep -c $DRIVER_NAME $SOURCE/$KERNEL_DIR/${PREFFIX}/Kconfig) -gt 1 ]] && \
        sed -i '0,/wireguard/{/wireguard/d;}' $SOURCE/$KERNEL_DIR/${PREFFIX}/Kconfig

        message "" "patching" "succeeded: $DRIVER_NAME"
        unset SOURCES
    fi

    if [[ $EXTERNAL_WIFI == yes ]]; then
        local PREFFIX="drivers/net/wireless"
        local SOURCES=()

        # <url>|<name>|<branch>
        # Wireless drivers for Realtek 8189ES chipsets
        SOURCES+=('https://github.com/jwrdegoede/rtl8189ES_linux|rtl8189es|master::')

        # Wireless drivers for Realtek 8189FS chipsets
        SOURCES+=('https://github.com/jwrdegoede/rtl8189ES_linux|rtl8189fs|rtl8189fs::')

        # Wireless drivers for Realtek 8192EU chipsets
        SOURCES+=('https://github.com/Mange/rtl8192eu-linux-driver|rtl8192eu|realtek-4.4.x::')

        ## Wireless drivers for Realtek 8811, 8812, 8814 and 8821 chipsets
        SOURCES+=('https://github.com/morrownr/8812au-20210629|rtl8812au|main::')

        # Wireless drivers for Xradio XR819 chipsets
        [[ $(version $KERNEL_VERSION) -ge $(version 5.4) && $(version $KERNEL_VERSION) -le $(version 5.19) ]] && \
        SOURCES+=('https://github.com/karabek/xradio|xradio|master::')

        # Wireless drivers for Realtek RTL8811CU and RTL8821C chipsets
        #SOURCES+=('https://github.com/brektrou/rtl8821CU|rtl8811cu|master:commit:2bebdb9a35c1d9b6e6a928e371fa39d5fcec8a62')
        SOURCES+=('https://github.com/morrownr/8821cu-20210118|rtl8811cu|main::')

        # Wireless drivers for Realtek 8188EU 8188EUS and 8188ETV chipsets
        SOURCES+=('https://github.com/aircrack-ng/rtl8188eus|rtl8188eu|v5.3.9::')

        # Wireless drivers for Realtek 88x2bu chipsets
        #SOURCES+=('https://github.com/cilynx/rtl88x2bu|rtl8822bu|5.8.7.1_35809.20191129_COEX20191120-7777::')
        SOURCES+=('https://github.com/morrownr/88x2bu-20210702|rtl8822bu|main::')

        # Wireless drivers for Realtek 88x2cs chipsets
        SOURCES+=('https://github.com/jethome-ru/rtl88x2cs|rtl8822cs|tune_for_jethub::')

        # Wireless drivers for Realtek 8723DS chipsets
        [[ $(version $KERNEL_VERSION) -ge $(version 5.4) ]] && \
        SOURCES+=('https://github.com/lwfinger/rtl8723ds|rtl8723ds|master::')

        # Wireless drivers for Realtek 8723DU chipsets
        [[ $(version $KERNEL_VERSION) -ge $(version 5.4) ]] && \
        SOURCES+=('https://github.com/lwfinger/rtl8723du|rtl8723du|master::')

        # Wireless drivers for Realtek 8814AU chipsets
        SOURCES+=('https://github.com/morrownr/8814au|rtl8814au|main::')



        for src in "${SOURCES[@]}";do
            IFS='|'
            local source_array=($src)
            unset IFS
            local DRIVER_URL="${source_array[0]}"
            local DRIVER_NAME="${source_array[1]}"
            local DRIVER_BRANCH="${source_array[2]}"

            [[ -d $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME ]] && ( rm -rf $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME || (message "err" "details" && exit 1) || exit 1 )
            message "" "download" "external driver $DRIVER_NAME"
            # git_fetch <dir> <url> <branch>
            git_fetch $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME $DRIVER_URL $DRIVER_BRANCH
            # clean .git
            [[ -d $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/.git ]] && ( rm -rf $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/.git || (message "err" "details" && exit 1) || exit 1 )

            if [[ $DRIVER_NAME == rtl8811cu ]]; then
                # Address ARM related bug https://github.com/aircrack-ng/rtl8812au/issues/233
                sed -i "s/^CONFIG_MP_VHT_HW_TX_MODE.*/CONFIG_MP_VHT_HW_TX_MODE = n/" \
                "$SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Makefile"
            fi

            if [[ $DRIVER_NAME == rtl8723du ]]; then
                echo -e "config RTL8723DU" > $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Kconfig
                echo -e "\ttristate \"Realtek 8723D USB WiFi\"" >> $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Kconfig
                echo -e "\thelp" >> $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Kconfig
                echo -e "\t  Help message of RTL8723DU" >> $SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Kconfig
                sed -i 's/export TopDIR ?= \$(shell pwd)/export TopDIR ?= \$(src)/g' "$SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Makefile"
            fi

            # Kconfig
            sed -i 's/---help---/help/g' "$SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Kconfig"

            # Disable debug
            sed -i "s/^CONFIG_RTW_DEBUG.*/CONFIG_RTW_DEBUG = n/" \
            "$SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/Makefile"

            # Add to section Makefile
            echo "obj-\$(CONFIG_${DRIVER_NAME^^}) += $DRIVER_NAME/" >> "$SOURCE/$KERNEL_DIR/${PREFFIX}/Makefile"
            sed -i "/source \"drivers\/net\/wireless\/ti\/Kconfig\"/a source \"drivers\/net\/wireless\/$DRIVER_NAME\/Kconfig\"" \
            "$SOURCE/$KERNEL_DIR/${PREFFIX}/Kconfig"

            if [[ $DRIVER_NAME == xradio ]]; then
                # fixed Makefile Xradio XR819
                sed -i 's:CONFIG_XRADIO:CONFIG_WLAN_VENDOR_XRADIO:' "$SOURCE/$KERNEL_DIR/${PREFFIX}/Makefile"

                [[ $(version $KERNEL_VERSION) -ge $(version 5.4) ]] && sed -i 's/^#include <asm\/mach-types.h>/\/\/#include <asm\/mach-types.h>/' "$SOURCE/$KERNEL_DIR/${PREFFIX}/$DRIVER_NAME/sdio.c"
            fi

            message "" "patching" "succeeded: $DRIVER_NAME"
        done
    fi
}

#---------------------------------------------
# get gcc version
#---------------------------------------------
gcc_version() {
    local VER
    #VER=$( ${1}gcc --version | grep -oP "GCC.*(?=\))" )
    #VER=$( ${1}gcc --version | grep 'GCC\|Toolchain' | rev | cut -d ')' -f1 | rev | sed 's:^\s::g' )
    VER=$( ${1}gcc --version | rev | cut -d ')' -f1 | rev | head -n 1 | sed 's:^\s::g' )
    eval "$2=\$VER"
}

#---------------------------------------------
# read packages
#---------------------------------------------
read_packages() {
    local TYPE="$1"
    local PKG
    local PKG_PATH
    if [[ -e $CWD/config/packages/${DISTR}/${ARCH}/${DISTR_VERSION}/packages-${TYPE}.conf ]]; then
        PKG_PATH=$CWD/config/packages/${DISTR}/${ARCH}/${DISTR_VERSION}/packages-${TYPE}.conf
    elif [[ -e $CWD/config/packages/${DISTR}/${ARCH}/${DISTR_VERSION}/${ARCH}/packages-${TYPE}.conf ]]; then
        PKG_PATH=$CWD/config/packages/${DISTR}/${ARCH}/${DISTR_VERSION}/${ARCH}/packages-${TYPE}.conf
    fi
    [[ ! -z ${PKG_PATH} ]] && PKG=( $(grep -vP "^#|^$" ${PKG_PATH}) )
    eval "$2=\${PKG[*]}"
}


#---------------------------------------------
# change the name of the version u-boot kernel
#---------------------------------------------
change_name_version() {
    local SUFFIX="$1"
    [[ -f .config ]] && sed -i "s/CONFIG_LOCALVERSION=\"\"/CONFIG_LOCALVERSION=\"$SUFFIX\"/g" .config
    [[ -f .config ]] && sed -i "s/CONFIG_LOCALVERSION_AUTO=.*/# CONFIG_LOCALVERSION_AUTO is not set/g" .config

    # prevent adding + to kernel release
    echo -n > .scmversion
}


#---------------------------------------------
# aarch64 change interpreter path
#---------------------------------------------
change_interpreter_path() {
    local EXECUTE_PATH="$@"
    for dir in ${EXECUTE_PATH[@]}; do
        if [[ -d "$SOURCE/$dir" ]]; then
            find "$SOURCE/$dir" | xargs file | grep -e "executable\(.*\)interpreter" \
            | grep ELF | cut -f1 -d ':' \
            | xargs -I '{}' patchelf --set-interpreter /lib64/ld-linux-aarch64.so.1 '{}' >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    done
}


#---------------------------------------------
# clear boot tools
#---------------------------------------------
clear_boot_tools() {
    message "" "clear" "boot tools"
    [[ -d $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot ]] && rm -rf $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot
    return 0
}


#---------------------------------------------
# create image
#---------------------------------------------
create_img() {
    local IMAGE="$1"

    [[ -z "$IMAGE" ]] && exit 1

    # +1600M for create swap firstrun
    ROOTFS_SIZE=$(rsync -an --stats $SOURCE/$IMAGE test | grep "Total file size" | sed 's/[^0-9]//g' | xargs -I{} expr {} / $((1024*1024)) + 2200)"M"

    message "" "create" "image size $ROOTFS_SIZE"

    dd if=/dev/zero of=$SOURCE/$IMAGE.img bs=1 count=0 seek=$ROOTFS_SIZE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}


#---------------------------------------------
# preparing a chroot environment
#---------------------------------------------
prepare_chroot() {
    local TYPE="$1"
    message "" "${TYPE}" "chroot for $ARCH"
    BINFMT_MISC_PATH="/proc/sys/fs/binfmt_misc"

    if [[ ${TYPE} == "prepare" ]]; then
        if [[ ! $(mount | grep binfmt_misc) ]]; then
            modprobe binfmt_misc >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            mount binfmt_misc -t binfmt_misc $BINFMT_MISC_PATH >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            echo 1 > $BINFMT_MISC_PATH/status | tee -a $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi

        # uregister arch
        [[ -e $BINFMT_MISC_PATH/qemu-${ARCH} ]] && ( echo -1 > $BINFMT_MISC_PATH/qemu-${ARCH} | tee -a $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

        # register arch
        cat $CWD/blobs/qemu-static/${MARCH}/qemu-${ARCH}.conf > $BINFMT_MISC_PATH/register | tee -a $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        install -Dm755 $CWD/blobs/qemu-static/${MARCH}/qemu-${ARCH}-static $SOURCE/$ROOTFS/usr/bin >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    elif [[ ${TYPE} == "cleaning" ]]; then
        # uregister arch
        [[ -e $BINFMT_MISC_PATH/qemu-${ARCH} ]] && ( echo -1 > $BINFMT_MISC_PATH/qemu-${ARCH} | tee -a $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )

        rm $SOURCE/$ROOTFS/usr/bin/qemu-${ARCH}-static >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
}


