# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x39000000"
# default values
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv console "both"
setenv rootfstype "ext4"
setenv earlycon "off"

# boot from eMMC
part uuid mmc 1 part_exists

if test -n ${part_exists}; then
        setenv rootdev "/dev/mmcblk0p1"
        setenv devnum "1"
fi

echo "Boot script loaded from ${devtype} ${devnum}"

if load ${devtype} ${devnum} ${load_addr} ${prefix}uEnv.txt; then
    env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=%SERIAL_CONSOLE%,%SERIAL_CONSOLE_SPEED%n8"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} earlyprintk console=tty1"; fi
if test "${earlycon}" = "on"; then setenv consoleargs "earlycon ${consoleargs}"; fi

setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} init=/sbin/init ${consoleargs} consoleblank=0 loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} ${extraargs}"

load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}zImage
fdt addr ${fdt_addr_r}
fdt resize 65536

if ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd; then
    bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r};
else
    bootz ${kernel_addr_r} - ${fdt_addr_r};
fi

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
