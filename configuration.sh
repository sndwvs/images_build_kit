#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

#---------------------------------------------
# board configuration
#---------------------------------------------
get_config

#---------------------------------------------
# boot loader configuration
#---------------------------------------------
URL_BOOT_LOADER_SOURCE="http://git.denx.de"
BOOT_LOADER="u-boot"
BOOT_LOADER_BRANCH="" #>v2017.05

#---------------------------------------------
# xtools configuration
#---------------------------------------------
URL_XTOOLS="https://releases.linaro.org/components/toolchain/binaries"
XTOOLS_ARM_SUFFIX="arm-linux-gnueabihf"
XTOOLS_ARM64_SUFFIX="aarch64-linux-gnu"
XTOOLS_PREFIX="gcc-linaro"
if [[ $KERNEL_SOURCE != next ]]; then
    BASE_VERSION_XTOOLS="5.4-2017.05"
    VERSION_XTOOLS="5.4.1-2017.05"
#    BASE_VERSION_XTOOLS="4.9-2017.01"
#    VERSION_XTOOLS="4.9.4-2017.01"
else
    BASE_VERSION_XTOOLS="6.3-2017.05"
    VERSION_XTOOLS="6.3.1-2017.05"
fi
ARM_XTOOLS="$XTOOLS_PREFIX-$VERSION_XTOOLS-$(uname -m)_$XTOOLS_ARM_SUFFIX"
ARM64_XTOOLS="$XTOOLS_PREFIX-$VERSION_XTOOLS-$(uname -m)_$XTOOLS_ARM64_SUFFIX"
URL_ARM_XTOOLS="$URL_XTOOLS/$BASE_VERSION_XTOOLS/$XTOOLS_ARM_SUFFIX/$ARM_XTOOLS"
URL_ARM64_XTOOLS="$URL_XTOOLS/$BASE_VERSION_XTOOLS/$XTOOLS_ARM64_SUFFIX/$ARM64_XTOOLS"

#---------------------------------------------
# rootfs configuration
#---------------------------------------------
#URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
URL_ROOTFS="http://dl.fail.pp.ua/slackware/minirootfs/"
ROOTFS_NAME=$(wget -q -O - $URL_ROOTFS | grep -oP "(slack-current-${ARCH}[\.\-\+\d\w]+.tar.xz)" | sort -ur | head -n1 | cut -d '.' -f1)
ROOTFS_VERSION=$(date +%Y%m%d)

#---------------------------------------------
# cross compilation
#---------------------------------------------
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$CWD/$BUILD/${SOURCE}/$ARM_XTOOLS/bin:$CWD/$BUILD/${SOURCE}/$ARM64_XTOOLS/bin:$CWD/$BUILD/$OUTPUT/$TOOLS/
export CROSS="${XTOOLS_ARM_SUFFIX}-"
export CROSS64="${XTOOLS_ARM64_SUFFIX}-"

#---------------------------------------------
# packages
#---------------------------------------------
#URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-14.2/slackware"
[[ $ARCH == arm ]] && URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-current/slackware"
[[ $ARCH == aarch64 ]] && URL_DISTR="http://dl.fail.pp.ua/slackware/slarm64-current/slackware"
URL_DISTR_EXTRA="http://dl.fail.pp.ua/slackware/pkg/${ARCH}"

#---------------------------------------------
# claear enviroment
#---------------------------------------------
clean_sources (){
    #rm -rf $CWD/$BUILD/{$SOURCE/{$XTOOLS,$XTOOLS_OLD},$PKG,$OUTPUT/{$TOOLS,$FLASH}}
    rm -rf $CWD/$BUILD/ || exit 1
}

#---------------------------------------------
# create enviroment
#---------------------------------------------
prepare_dest (){
    mkdir -p $CWD/$BUILD/{$SOURCE/$XTOOLS,$PKG,$OUTPUT/{$TOOLS,$FLASH}} || exit 1
}

