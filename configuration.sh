#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

#---------------------------------------------
# board configuration
#---------------------------------------------
get_config

#---------------------------------------------
# mainline kernel source configuration
#---------------------------------------------
if [[ $KERNEL_SOURCE == next ]]; then
    LINUX_SOURCE=${LINUX_SOURCE:-"https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable"}
    #LINUX_SOURCE='git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git'
    KERNEL_BRANCH=${KERNEL_BRANCH:-"linux-4.19.y::"}
    KERNEL_DIR=${KERNEL_DIR:-"linux-$KERNEL_SOURCE"}
fi

#---------------------------------------------
# boot loader configuration
#---------------------------------------------
BOOT_LOADER_SOURCE=${BOOT_LOADER_SOURCE:-"https://git.denx.de/u-boot.git"}
BOOT_LOADER_DIR=${BOOT_LOADER_DIR:-"u-boot"}
BOOT_LOADER_BRANCH=${BOOT_LOADER_BRANCH:-"master::"} #"master:tag:v2017.05"

#---------------------------------------------
# xtools configuration
#---------------------------------------------
if [[ $NATIVE_ARCH != true ]]; then
    BASE_URL_XTOOLS="https://releases.linaro.org/components/toolchain/binaries"
    XTOOLS_ARM_SUFFIX="arm-linux-gnueabihf"
    XTOOLS_ARM64_SUFFIX="aarch64-linux-gnu"
    XTOOLS_PREFIX="gcc-linaro"

    OLD_BASE_VERSION_XTOOLS="5.5-2017.10"
    OLD_VERSION_XTOOLS="5.5.0-2017.10"
#    OLD_BASE_VERSION_XTOOLS="4.9-2017.01"
#    OLD_VERSION_XTOOLS="4.9.4-2017.01"
    BASE_VERSION_XTOOLS="7.2-2017.11"
    VERSION_XTOOLS="7.2.1-2017.11"

    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-$(uname -m)_$XTOOLS_ARM_SUFFIX")
    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-$(uname -m)_$XTOOLS_ARM64_SUFFIX")
    XTOOLS+=("$XTOOLS_PREFIX-$OLD_VERSION_XTOOLS-$(uname -m)_$XTOOLS_ARM_SUFFIX")
    XTOOLS+=("$XTOOLS_PREFIX-$OLD_VERSION_XTOOLS-$(uname -m)_$XTOOLS_ARM64_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/$XTOOLS_ARM_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/$XTOOLS_ARM64_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$OLD_BASE_VERSION_XTOOLS/$XTOOLS_ARM_SUFFIX")
    URL_XTOOLS+=("$BASE_URL_XTOOLS/$OLD_BASE_VERSION_XTOOLS/$XTOOLS_ARM64_SUFFIX")
fi

#if [[ $ARCH == aarch64 ]]; then
#    BASE_URL_XTOOLS="http://dl.fail.pp.ua/slackware/xtools"
#    XTOOLS_ARM_SUFFIX="arm-slackware-linux-gnueabihf"
#    XTOOLS_PREFIX="gcc"
#    BASE_VERSION_XTOOLS="8.2-2019.02"
#    VERSION_XTOOLS="8.2.0-2019.02"

#    XTOOLS+=("$XTOOLS_PREFIX-$VERSION_XTOOLS-$(uname -m)_$XTOOLS_ARM_SUFFIX")
#    URL_XTOOLS+=("$BASE_URL_XTOOLS/$BASE_VERSION_XTOOLS/$XTOOLS_ARM_SUFFIX")
#fi


#---------------------------------------------
# rootfs configuration
#---------------------------------------------
if [[ $ARCH == arm ]] ;then
    URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
else
    URL_ROOTFS="http://dl.fail.pp.ua/slackware/minirootfs/"
fi
ROOTFS_NAME=$(wget -q -O - $URL_ROOTFS | grep -oP "(sla(ck|rm64)-current-${ARCH}[\.\-\+\d\w]+.tar.xz)" | sort -ur | head -n1 | cut -d '.' -f1)
ROOTFS_VERSION=$(date +%Y%m%d)

#---------------------------------------------
# cross compilation
#---------------------------------------------
for XTOOL in ${XTOOLS[*]}; do
    if [[ $(echo $XTOOL | grep $ARCH) ]]; then
        [[ $(echo $XTOOLS_ARM_SUFFIX | grep $ARCH) ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM_SUFFIX
        [[ $(echo $XTOOLS_ARM64_SUFFIX | grep $ARCH) ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM64_SUFFIX
#        VER=$(echo $XTOOL | cut -f3 -d "-")
        VER=$(echo $XTOOL | sed 's/^.*-\([0-9].[0-9].[0-9]*\)-.*/\1/')
        if [[ $VER > 6 ]]; then
            export CROSS="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
        else
            export OLD_CROSS="${SOURCE}/$XTOOL/bin/${_XTOOLS_ARM_SUFFIX}-"
        fi
#        echo $XTOOL $VER
    fi

    if [[ $ARCH != arm ]] && [[ $(echo $XTOOL | grep arm) ]]; then
        [[ $(echo $XTOOLS_ARM_SUFFIX | grep arm) ]] && _XTOOLS_ARM_SUFFIX=$XTOOLS_ARM_SUFFIX
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

[[ $NATIVE_ARCH == true ]] && export CROSS="" OLD_CROSS=""

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$BUILD/$OUTPUT/$TOOLS/
#export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$SOURCE/$ARM_XTOOLS/bin:$SOURCE/$ARM64_XTOOLS/bin:$BUILD/$OUTPUT/$TOOLS/
#export CROSS="${XTOOLS_ARM_SUFFIX}-"
#export CROSS64="${XTOOLS_ARM64_SUFFIX}-"

#---------------------------------------------
# packages
#---------------------------------------------
#URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-14.2/slackware"
[[ $ARCH == arm ]] && URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-current/slackware"
[[ $ARCH == aarch64 ]] && URL_DISTR="http://dl.fail.pp.ua/slackware/slarm64-current/slarm64"
URL_DISTR_EXTRA="http://dl.fail.pp.ua/slackware/pkg/${ARCH}"

#---------------------------------------------
# claear enviroment
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

