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
BOOT_LOADER_BRANCH="" #>v2016.07

#---------------------------------------------
# xtools configuration
#---------------------------------------------
XTOOLS="x-tools7h"
if [[ $SOCFAMILY == sun* ]] && [[ $KERNEL_SOURCE != next ]]; then
    VERSION_XTOOLS="5.3.0-5"
    MD5_XTOOLS="43562de45d89d1d7de9193c44b2e6909"
elif [[ $SOCFAMILY == rk3288 ]]; then
    VERSION_XTOOLS="4.9.2-4"
    MD5_XTOOLS="ccbfa040c1949dad6d32505fa9d973b9"
else
    VERSION_XTOOLS="6.1.1-4"
    MD5_XTOOLS="2e78ef5e1241bfb8e35e2fc3132d68f1"
fi
URL_XTOOLS="https://archlinuxarm.org/builder/xtools/$VERSION_XTOOLS/$XTOOLS.tar.xz"

#---------------------------------------------
# rootfs configuration
#---------------------------------------------
#URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
URL_ROOTFS="http://dl.fail.pp.ua/slackware/minirootfs/"
ROOTFS_NAME=$(wget -q -O - $URL_ROOTFS | grep -oP "(slack-current[\.\-\+\d\w]+.tar.xz)" | sort -ur | head -n1 | cut -d '.' -f1)
ROOTFS_VERSION=$(date +%Y%m%d)

#---------------------------------------------
# cross compilation
#---------------------------------------------
export PATH=$PATH:$CWD/$BUILD/${SOURCE}/$XTOOLS_OLD/bin:$CWD/$BUILD/${SOURCE}/$XTOOLS/arm-unknown-linux-gnueabihf/bin:$CWD/$BUILD/$OUTPUT/$TOOLS/
CROSS_OLD="arm-eabi-"
CROSS="arm-unknown-linux-gnueabihf-"

#---------------------------------------------
# packages
#---------------------------------------------
#URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-14.2/slackware"
URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-current/slackware"
URL_DISTR_EXTRA="http://dl.fail.pp.ua/slackware/pkg/arm"

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

