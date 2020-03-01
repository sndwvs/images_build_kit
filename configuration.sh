#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

#---------------------------------------------
# mainline kernel source configuration
#---------------------------------------------
LINUX_SOURCE=${LINUX_SOURCE:-"https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable"}
#LINUX_SOURCE='git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git'
KERNEL_BRANCH=${KERNEL_BRANCH:-"linux-5.4.y::"}
KERNEL_DIR=${KERNEL_DIR:-"linux-$KERNEL_SOURCE"}

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
BOOT_LOADER_SOURCE=${BOOT_LOADER_SOURCE:-"https://git.denx.de/u-boot.git"}
BOOT_LOADER_DIR=${BOOT_LOADER_DIR:-"u-boot"}
BOOT_LOADER_BRANCH=${BOOT_LOADER_BRANCH:-"master::"} #"master:tag:v2017.05"

#---------------------------------------------
# arm trusted firmware configuration
#---------------------------------------------
ATF_SOURCE=${ATF_SOURCE:-"https://github.com/ARM-software/arm-trusted-firmware.git"}
ATF_DIR=${ATF_DIR:-"arm-trusted-firmware"}
ATF_BRANCH=${ATF_BRANCH:-"master:commit:22d12c4148c373932a7a81e5d1c59a767e143ac2"}




#---------------------------------------------
# board configuration
#---------------------------------------------
get_config




#---------------------------------------------
# xtools configuration
#---------------------------------------------
if [[ $MARCH == "x86_64" ]]; then
    BASE_URL_XTOOLS="https://releases.linaro.org/components/toolchain/binaries"
    XTOOLS_ARM_SUFFIX="arm-linux-gnueabihf"
    XTOOLS_ARM64_SUFFIX="aarch64-linux-gnu"
    XTOOLS_PREFIX="gcc-linaro"

    OLD_BASE_VERSION_XTOOLS="5.5-2017.10"
    OLD_VERSION_XTOOLS="5.5.0-2017.10"
    BASE_VERSION_XTOOLS="7.2-2017.11"
    VERSION_XTOOLS="7.2.1-2017.11"

    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-${ARCH}_$XTOOLS_ARM_SUFFIX")
    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-${ARCH}_$XTOOLS_ARM64_SUFFIX")
    XTOOLS+=("$XTOOLS_PREFIX-$OLD_VERSION_XTOOLS-${ARCH}_$XTOOLS_ARM_SUFFIX")
    XTOOLS+=("$XTOOLS_PREFIX-$OLD_VERSION_XTOOLS-${ARCH}_$XTOOLS_ARM64_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/$XTOOLS_ARM_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/$XTOOLS_ARM64_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$OLD_BASE_VERSION_XTOOLS/$XTOOLS_ARM_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$OLD_BASE_VERSION_XTOOLS/$XTOOLS_ARM64_SUFFIX")
elif [[ $MARCH == "aarch64" ]]; then
    # https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-aarch64-arm-none-linux-gnueabihf.tar.xz
    BASE_URL_XTOOLS="https://developer.arm.com/-/media/Files/downloads/gnu-a"
    XTOOLS_ARM_SUFFIX="arm-none-linux-gnueabihf"
    XTOOLS_PREFIX="gcc-arm"
    BASE_VERSION_XTOOLS="9.2-2019.12"
    VERSION_XTOOLS=$BASE_VERSION_XTOOLS
    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-$ARCH-$XTOOLS_ARM_SUFFIX")
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
        if [[ $XTOOL =~ "aarch64" ]]; then
            [[ $XTOOLS_ARM_SUFFIX =~ "arm" ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM_SUFFIX
            [[ $XTOOLS_ARM64_SUFFIX =~ "aarch64" ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM64_SUFFIX
    #        VER=$(echo $XTOOL | cut -f3 -d "-")
            VER=$(echo $XTOOL | sed 's/^.*-\([0-9].[0-9].[0-9]*\)-.*/\1/')
            if [[ $VER > 6 ]]; then
                export CROSS="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
            else
                export OLD_CROSS="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
            fi
    #        echo $XTOOL $VER
        fi
        if [[ $ARCH != "arm" ]] && [[ $XTOOL =~ "arm" ]]; then
            [[ $XTOOLS_ARM_SUFFIX =~ "arm" ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM_SUFFIX
    #        VER=$(echo $XTOOL | cut -f3 -d "-")
            VER=$(echo $XTOOL | sed 's/^.*-\([0-9].[0-9].[0-9]*\)-.*/\1/')
            if [[ $VER > 6 ]]; then
                export CROSS32="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
            else
                export OLD_CROSS32="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
            fi
    #        echo $XTOOL $VER
        fi
    done
fi

[[ $MARCH != "x86_64" ]] && export CROSS="" OLD_CROSS=""

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

