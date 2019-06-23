# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x39000000"
# default values
setenv rootdev "/dev/mmcblk0p1"
setenv fdt_file "rk3328-rock64.dtb"
setenv verbosity "4"
setenv console "both"
setenv rootfstype "ext4"

# boot from SD
part uuid ${devtype} 1 part_exists

if test -n ${part_exists}; then
    setenv rootdev "/dev/mmcblk1p1"
    setenv devnum "1"
    ${devtype} dev ${devnum}
fi

if load ${devtype} ${devnum}:1 ${load_addr} ${prefix}uEnv.txt; then
    env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=%SERIAL_CONSOLE%,%SERIAL_CONSOLE_SPEED%n8"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} console=tty1"; fi

setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} init=/sbin/init ${consoleargs} panic=10 consoleblank=0 loglevel=${verbosity} ${extraargs}"

load ${devtype} ${devnum}:1 ${fdt_addr_r} ${prefix}dtb/${fdt_file}
load ${devtype} ${devnum}:1 ${kernel_addr_r} ${prefix}Image
fdt addr ${fdt_addr_r}
fdt resize 65536
booti ${kernel_addr_r} - ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
