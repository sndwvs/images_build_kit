# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x00000000"
setenv rootdev "/dev/mmcblk1p6"
setenv fdt_file "rk3399-firefly-linux.dtb"
setenv console "both"
setenv verbosity "1"

# boot from eMMC
part uuid mmc 1 part_exists

if test -n ${part_exists}; then
    setenv rootdev "/dev/mmcblk0p1"
    setenv devnum "1"
fi

itest.b ${devnum} == 0 && echo "U-boot loaded from eMMC"
itest.b ${devnum} == 1 && echo "U-boot loaded from SD"

if load ${devtype} ${devnum}:1 ${load_addr} ${prefix}uEnv.txt; then
    env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=ttyS1,1500000n8"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} earlyprintk console=tty1"; fi

setenv bootargs "consoleblank=0 root=${rootdev} ro rootwait rootfstype=ext4 init=/sbin/init ${consoleargs} loglevel=${verbosity} ${extraargs}"

load ${devtype} ${devnum}:1 ${fdt_addr_r} ${prefix}dtb/${fdt_file}
load ${devtype} ${devnum}:1 ${kernel_addr_r} ${prefix}Image
booti ${kernel_addr_r} - ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
