#!/bin/bash



CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS=" -j$(($CPUS + $CPUS/2)) ";



#---------------------------------------------
# environment
#---------------------------------------------
CWD=$(pwd)
BUILD="build"
SOURCE="source"
PKG="pkg"
OUTPUT="output"
TOOLS="tools"
FLASH="flash"



#---------------------------------------------
# resources
#---------------------------------------------
URL_LINUX_UPGRADE_TOOL="http://dl.radxa.com/rock/tools/linux/"
LINUX_UPGRADE_TOOL="Linux_Upgrade_Tool_v1.21"
URL_XTOOLS_OLD="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7/"
URL_XTOOLS="http://archlinuxarm.org/builder/xtools/x-tools7h.tar.xz"
XTOOLS_OLD="x-tools7h_old"
XTOOLS="x-tools7h"
URL_RK2918_TOOLS="https://github.com/TeeFirefly/"
RK2918_TOOLS="rk2918_tools"
URL_RKFLASH_TOOLS="https://github.com/neo-technologies/"
RKFLASH_TOOLS="rkflashtool"
URL_MKBOOTIMG_TOOLS="https://github.com/neo-technologies/"
MKBOOTIMG_TOOLS="rockchip-mkbootimg"
URL_BOOT_LOADER_SOURCE="https://github.com/linux-rockchip/"
BOOT_LOADER="u-boot-rockchip"
BOOT_LOADER_CONFIG="rk3288_defconfig"
URL_FIRMWARE="https://github.com/rkchrome/overlay/archive/"
FIRMWARE="master.zip"
URL_LINUX_SOURCE="https://bitbucket.org/T-Firefly"
LINUX_SOURCE="firefly-rk3288-kernel"
LINUX_CONFIG="rk3288_config"
MODULES="mali_kbase gspca_main"
URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
ROOTFS="slack-current-miniroot_09Mar15"
VERSION=$(date +%Y%m%d)
ROOT_DISK="mmcblk0p3"
ROOTFS_SIZE="512M"



#---------------------------------------------
# croos compilation
#---------------------------------------------
export PATH=$PATH:$CWD/$BUILD/${SOURCE}/$XTOOLS_OLD/bin:$CWD/$BUILD/${SOURCE}/$XTOOLS/arm-unknown-linux-gnueabihf/bin:$CWD/$BUILD/$OUTPUT/$TOOLS/
CROSS_OLD="arm-eabi-"
CROSS="arm-unknown-linux-gnueabihf-"



#---------------------------------------------
# create dir
#---------------------------------------------
#rm -rf ${CWD}/$BUILD/{$SOURCE/{$XTOOLS,$XTOOLS_OLD},$PKG,$OUTPUT/{$TOOLS,$FLASH}}
mkdir -p ${CWD}/$BUILD/{$SOURCE/$XTOOLS,$PKG,$OUTPUT/{$TOOLS,$FLASH}}





