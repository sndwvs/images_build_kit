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
BOOT_LOADER_VERSION="" #>v2016.03

#---------------------------------------------
# xtools configuration
#---------------------------------------------
XTOOLS="x-tools7h"
if [[ $SOCFAMILY == sun* ]] && [[ $KERNEL_SOURCE != next ]]; then
    URL_XTOOLS="https://archlinuxarm.org/builder/xtools/5.3.0-5/$XTOOLS.tar.xz"
elif [[ $SOCFAMILY == rk3288 ]] && [[ $KERNEL_SOURCE != next ]]; then
    URL_XTOOLS="https://archlinuxarm.org/builder/xtools/4.9.2-4/$XTOOLS.tar.xz"
else
    URL_XTOOLS="http://archlinuxarm.org/builder/xtools/$XTOOLS.tar.xz"
fi

#---------------------------------------------
# rootfs configuration
#---------------------------------------------
URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
ROOTFS_NAME=$(wget -q -O - $URL_ROOTFS | grep -oP "(slack-current[\.\-\+\d\w]+.tar.xz)" | head -n1 | cut -d '.' -f1)
ROOTFS_VERSION=$(date +%Y%m%d)

#---------------------------------------------
# cross compilation
#---------------------------------------------
export PATH=$PATH:$CWD/$BUILD/${SOURCE}/$XTOOLS_OLD/bin:$CWD/$BUILD/${SOURCE}/$XTOOLS/arm-unknown-linux-gnueabihf/bin:$CWD/$BUILD/$OUTPUT/$TOOLS/
CROSS_OLD="arm-eabi-"
CROSS="arm-unknown-linux-gnueabihf-"

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

