#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

#---------------------------------------------
# mainline kernel source configuration
#---------------------------------------------
LINUX_SOURCE=${LINUX_SOURCE:-"https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable"}
#LINUX_SOURCE='git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git'
KERNEL_BRANCH=${KERNEL_BRANCH:-"linux-5.9.y::"}
KERNEL_DIR=${KERNEL_DIR:-"linux-$KERNEL_SOURCE"}

#---------------------------------------------
# mainline kernel firmware configuration
#---------------------------------------------
KERNEL_FIRMWARE_SOURCE=${KERNEL_FIRMWARE_SOURCE:-"git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"}
KERNEL_FIRMWARE_BRANCH=${KERNEL_FIRMWARE_BRANCH:-"master::"}
KERNEL_FIRMWARE_DIR=${KERNEL_FIRMWARE_DIR:-"linux-firmware"}

#---------------------------------------------
# configuration linux distribution
#---------------------------------------------
DISTR=${DISTR:-"slackwarearm"}
DISTR_VERSION=${DISTR_VERSION:-"current"} # or 14.2

#---------------------------------------------
# configuration build images
#---------------------------------------------
#DISTR_IMAGES=${DISTR_IMAGES:-"mini"}

#---------------------------------------------
# boot loader configuration
#---------------------------------------------
if [[ $USE_UBOOT_MIRROR == yes ]]; then
    BOOT_LOADER_SOURCE=${BOOT_LOADER_SOURCE:-"https://github.com/u-boot/u-boot.git"}
else
    BOOT_LOADER_SOURCE=${BOOT_LOADER_SOURCE:-"git://gitlab.denx.de/u-boot/u-boot.git"}
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
# board configuration
#---------------------------------------------
source $CWD/overall.sh || exit 1
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

    BASE_VERSION_XTOOLS="9.2-2019.12"
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
    BASE_VERSION_XTOOLS="9.2-2019.12"
    VERSION_XTOOLS=$BASE_VERSION_XTOOLS
    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-${MARCH}-$XTOOLS_ARM_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/binrel")
fi


#---------------------------------------------
# rootfs configuration
#---------------------------------------------
if [[ ${DISTR} == slackwarearm ]];then
    URL_ROOTFS="https://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
else
    URL_ROOTFS="http://dl.fail.pp.ua/slackware/rootfs/"
fi
ROOTFS_NAME=$(wget --no-check-certificate -q -O - $URL_ROOTFS | grep -oP "(sla(ck|rm64)-current-[\.\-\+\d\w]+.tar.xz)" | sort -ur | head -n1 | cut -d '.' -f1)
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
    done
fi

[[ $MARCH != "x86_64" ]] && export CROSS=""
[[ $MARCH == "aarch64" && $KARCH == "arm" ]] && export CROSS=$CROSS32

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$BUILD/$OUTPUT/$TOOLS/
#export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$SOURCE/$ARM_XTOOLS/bin:$SOURCE/$ARM64_XTOOLS/bin:$BUILD/$OUTPUT/$TOOLS/
#export CROSS="${XTOOLS_ARM_SUFFIX}-"
#export CROSS64="${XTOOLS_ARM64_SUFFIX}-"

#---------------------------------------------
# packages
#---------------------------------------------
if [[ ${DISTR} == slackwarearm ]];then
    DISTR_DIR=${DISTR/arm/}
else
    DISTR_DIR=${DISTR}
fi
DISTR_URL="http://dl.fail.pp.ua/slackware/${DISTR}-${DISTR_VERSION}/${DISTR_DIR}"
DISTR_EXTRA_URL="http://dl.fail.pp.ua/slackware/packages/${ARCH}"

#---------------------------------------------
# clean enviroment
#---------------------------------------------
clean_sources (){
    rm -rf $BUILD/ || exit 1
}

#---------------------------------------------
# create enviroment
#---------------------------------------------
prepare_dest (){
#    mkdir -p $BUILD/{$SOURCE/$PKG,$OUTPUT/{$TOOLS,$IMAGES}} || exit 1
    mkdir -p {$BUILD/$OUTPUT/{$TOOLS,$IMAGES},$SOURCE/$PKG} || exit 1
}

