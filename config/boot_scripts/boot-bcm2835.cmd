# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x39000000"
setenv rootdev "/dev/mmcblk0p1"
setenv console "both"
setenv verbosity "4"
setenv rootfstype "ext4"

if load ${devtype} ${devnum}:1 ${load_addr} ${prefix}uEnv.txt; then
    env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=%SERIAL_CONSOLE%,%SERIAL_CONSOLE_SPEED%n8"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} earlyprintk console=tty1"; fi

setenv bootargs "consoleblank=0 root=${rootdev} ro rootwait rootfstype=${rootfstype} init=/sbin/init ${consoleargs} loglevel=${verbosity} ${extraargs}"

load ${devtype} ${devnum}:1 ${fdt_addr_r} ${prefix}dtb/${fdtfile}
load ${devtype} ${devnum}:1 ${kernel_addr_r} ${prefix}Image

fdt addr ${fdt_addr_r}
#fdt get value bootargs /chosen bootargs
fdt resize 65536

if load ${devtype} ${devnum}:1 ${ramdisk_addr_r} ${prefix}uInitrd; then
    booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r};
else
    booti ${kernel_addr_r} - ${fdt_addr_r};
fi

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
