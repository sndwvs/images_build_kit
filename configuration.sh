#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

#---------------------------------------------
# mainline kernel source configuration
#---------------------------------------------
if [[ $USE_NEXT_KERNEL_MIRROR == yes ]]; then
    LINUX_SOURCE=${LINUX_SOURCE:-"https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable"}
else
    LINUX_SOURCE=${LINUX_SOURCE:-"git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"}
fi
KERNEL_BRANCH=${KERNEL_BRANCH:-"linux-6.0.y::"}
KERNEL_DIR=${KERNEL_DIR:-"linux-$KERNEL_SOURCE"}

#---------------------------------------------
# mainline kernel firmware configuration
#---------------------------------------------
KERNEL_FIRMWARE_SOURCE=${KERNEL_FIRMWARE_SOURCE:-"git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"}
KERNEL_FIRMWARE_BRANCH=${KERNEL_FIRMWARE_BRANCH:-"main::"}
KERNEL_FIRMWARE_DIR=${KERNEL_FIRMWARE_DIR:-"linux-firmware"}

#---------------------------------------------
# configuration linux distribution
#---------------------------------------------
if [[ $DISTR == sla* ]]; then
    [[ $DISTR == slackwarearm ]] && DISTR_VERSION="15.0"
    DISTR_VERSION=${DISTR_VERSION:-"current"} # or 15.0
elif [[ $DISTR == crux* ]]; then
    DISTR_VERSION=${DISTR_VERSION:-"3.6"}
fi

#---------------------------------------------
# configuration build images and desktop environment
#---------------------------------------------
#DISTR_IMAGES+=("server")
if [[ $DESKTOP_SELECTED == yes ]]; then
 if [[ -z $DE ]]; then
     DISTR_IMAGES+=("xfce")
 else
     DISTR_IMAGES+=($DE)
 fi
fi

#---------------------------------------------
# boot loader configuration
#---------------------------------------------
if [[ $USE_UBOOT_MIRROR == yes ]]; then
    BOOT_LOADER_SOURCE=${BOOT_LOADER_SOURCE:-"https://github.com/u-boot/u-boot.git"}
else
    BOOT_LOADER_SOURCE=${BOOT_LOADER_SOURCE:-"https://gitlab.denx.de/u-boot/u-boot.git"}
fi
BOOT_LOADER_DIR=${BOOT_LOADER_DIR:-"u-boot"}
BOOT_LOADER_BRANCH=${BOOT_LOADER_BRANCH:-"master::"} #"master:tag:v2017.05"

#---------------------------------------------
# arm trusted firmware configuration
#---------------------------------------------
ATF_SOURCE=${ATF_SOURCE:-"https://github.com/ARM-software/arm-trusted-firmware.git"}
ATF_DIR=${ATF_DIR:-"arm-trusted-firmware"}
ATF_BRANCH=${ATF_BRANCH:-"master::"}

#---------------------------------------------
# external wifi driver configuration
#---------------------------------------------
[[ -z $EXTERNAL_WIFI ]] && EXTERNAL_WIFI=yes

#---------------------------------------------
# external wireguard driver configuration
#---------------------------------------------
[[ -z $EXTERNAL_WIREGUARD ]] && EXTERNAL_WIREGUARD=yes


#---------------------------------------------
# board configuration
#---------------------------------------------
get_config




#---------------------------------------------
# xtools configuration
#---------------------------------------------
if [[ $MARCH == "x86_64" ]]; then
    # https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf.tar.xz
    # https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
    BASE_URL_XTOOLS="https://developer.arm.com/-/media/Files/downloads/gnu-a"
    XTOOLS_ARM_SUFFIX="arm-none-linux-gnueabihf"
    XTOOLS_ARM64_SUFFIX="aarch64-none-linux-gnu"
    XTOOLS_PREFIX="gcc-arm"

    BASE_VERSION_XTOOLS="10.3-2021.07"
    VERSION_XTOOLS=$BASE_VERSION_XTOOLS

    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-${MARCH}-$XTOOLS_ARM_SUFFIX")
    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-${MARCH}-$XTOOLS_ARM64_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/binrel")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/binrel")
elif [[ $MARCH == "aarch64" ]]; then
    # https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-aarch64-arm-none-linux-gnueabihf.tar.xz
    BASE_URL_XTOOLS="https://developer.arm.com/-/media/Files/downloads/gnu-a"
    XTOOLS_ARM_SUFFIX="arm-none-linux-gnueabihf"
    XTOOLS_PREFIX="gcc-arm"
    BASE_VERSION_XTOOLS="10.3-2021.07"
    VERSION_XTOOLS=$BASE_VERSION_XTOOLS
    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-${MARCH}-$XTOOLS_ARM_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/binrel")

    if [[ $ARCH == "riscv64" ]]; then
        # http://dl.slarm64.org/slackware/tools/gcc-riscv64-11.2-2021.11-aarch64-riscv64-unknown-linux-gnu.tar.xz
        BASE_URL_XTOOLS="http://dl.slarm64.org/slackware/tools"
        XTOOLS_RISCV64_SUFFIX="riscv64-unknown-linux-gnu"
        XTOOLS_PREFIX="gcc-riscv64"
        BASE_VERSION_XTOOLS="11.2-2021.11"
        VERSION_XTOOLS=$BASE_VERSION_XTOOLS
        XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-${MARCH}-$XTOOLS_RISCV64_SUFFIX")
        URL_XTOOLS+=("$BASE_URL_XTOOLS")
    fi
fi


#---------------------------------------------
# configuration distribution source base url
#---------------------------------------------
if [[ ${DISTR} == slackwarearm ]];then
    DISTR_SOURCE=${DISTR_SOURCE:-"http://dl.slarm64.org/slackware"}
elif [[ ${DISTR} == slarm64 ]];then
    if [[ $USE_SLARM64_MIRROR == yes ]]; then
        DISTR_SOURCE=${DISTR_SOURCE:-"https://osdn.net/projects/slarm64/storage"}
    else
        DISTR_SOURCE=${DISTR_SOURCE:-"http://dl.slarm64.org/slackware"}
    fi
elif [[ ${DISTR} == crux* ]];then
    DISTR_SOURCE=${DISTR_SOURCE:-"http://dl.slarm64.org/crux"}
fi

#---------------------------------------------
# rootfs configuration
#---------------------------------------------
ROOTFS_NAME=${DISTR/earm/e}-${DISTR_VERSION}
ROOTFS_VERSION=$(date +%Y%m%d)

#---------------------------------------------
# cross compilation
#---------------------------------------------
if [[ $MARCH == "x86_64" || $MARCH == "aarch64" ]]; then
    for XTOOL in ${XTOOLS[*]}; do
        if [[ $MARCH == "x86_64" && $XTOOL =~ "aarch64" ]]; then
            [[ $XTOOLS_ARM64_SUFFIX =~ "aarch64" ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM64_SUFFIX
            export CROSS="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
        fi
        if [[ $XTOOL =~ "gnueabihf" ]]; then
            [[ $XTOOLS_ARM_SUFFIX =~ "gnueabihf" ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM_SUFFIX
            export CROSS32="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
        fi
        if [[ $XTOOL =~ "riscv64" ]]; then
            [[ $XTOOLS_RISCV64_SUFFIX =~ "riscv64" ]] && _XTOOLS_RISCV64_SUFFIX=$XTOOLS_RISCV64_SUFFIX
            export CROSS="${SOURCE}/$XTOOL/bin/${_XTOOLS_RISCV64_SUFFIX}-"
        fi
    done
fi

[[ $MARCH != "x86_64" && $ARCH != "riscv64" ]] && export CROSS=""
[[ $MARCH == "aarch64" && $KARCH == "arm" ]] && export CROSS=$CROSS32

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$BUILD/$OUTPUT/$TOOLS/
#export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$SOURCE/$ARM_XTOOLS/bin:$SOURCE/$ARM64_XTOOLS/bin:$BUILD/$OUTPUT/$TOOLS/
#export CROSS="${XTOOLS_ARM_SUFFIX}-"
#export CROSS64="${XTOOLS_ARM64_SUFFIX}-"

#---------------------------------------------
# packages
#---------------------------------------------
if [[ ${DISTR} == slackwarearm ]]; then
    DISTR_DIR=${DISTR/arm/}
elif [[ ${DISTR} == slarm64 ]]; then
    DISTR_DIR=${DISTR}
elif [[ ${DISTR} == crux* ]]; then
    unset DISTR_DIR
    DISTR_IMAGES[0]="core"
fi
[[ $ARCH == riscv64 ]] && DISTR_SUFFIX="-$ARCH"
DISTR_URL="${DISTR_SOURCE}/${DISTR}${DISTR_SUFFIX}-${DISTR_VERSION}/${DISTR_DIR}"
DISTR_EXTRA_URL="${DISTR_SOURCE}/packages/${ARCH}"
#DISTR_URL="http://dl.slarm64.org/slackware/${DISTR}-${DISTR_VERSION}/${DISTR_DIR}"
#DISTR_EXTRA_URL="http://dl.slarm64.org/slackware/packages/${ARCH}"
if [[ ${DISTR} == crux* ]]; then
    if [[ ${ARCH} == aarch64 ]]; then
        DISTR_URL="${DISTR_SOURCE}/pkg/${DISTR_VERSION}-${ARCH}"
    else
        DISTR_URL="${DISTR_SOURCE}/pkg/${DISTR_VERSION}"
    fi
fi

#---------------------------------------------
# clean enviroment
#---------------------------------------------
clean_sources (){
    [[ -d $BUILD ]] && rm -rf $BUILD/ || exit 1
}

#---------------------------------------------
# create enviroment
#---------------------------------------------
prepare_dest (){
    mkdir -p {$BUILD/$OUTPUT/{$TOOLS,$IMAGES},$SOURCE} || exit 1
}

