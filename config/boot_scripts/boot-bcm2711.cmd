# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x02400000"
setenv rootdev "/dev/mmcblk0p2"
setenv console "both"
setenv verbosity "4"
setenv rootfstype "ext4"

if load ${devtype} ${devnum}:1 ${load_addr} uEnv.txt; then
    env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "earlyprintk console=tty1"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "console=%SERIAL_CONSOLE%,%SERIAL_CONSOLE_SPEED%n8 ${consoleargs}"; fi

fdt addr ${fdt_addr}
fdt get value bootargs /chosen bootargs

setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} init=/sbin/init ${consoleargs} loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} ${extraargs}"

fdt rm /chosen bootargs

load ${devtype} ${devnum}:1 ${kernel_addr_r} Image
load ${devtype} ${devnum}:1 ${fdt_addr_r} ${fdtfile}

if load ${devtype} ${devnum}:1 ${ramdisk_addr_r} uInitrd; then
    booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr};
else
    booti ${kernel_addr_r} - ${fdt_addr};
fi

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
