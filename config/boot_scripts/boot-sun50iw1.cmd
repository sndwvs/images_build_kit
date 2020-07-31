# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

# default values
setenv load_addr "0x45000000"
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv rootfstype "ext4"
setenv console "both"

# Print boot source
itest.b *0x10028 == 0x00 && echo "U-boot loaded from SD"
itest.b *0x10028 == 0x02 && echo "U-boot loaded from eMMC or secondary SD"
itest.b *0x10028 == 0x03 && echo "U-boot loaded from SPI"

echo "Boot script loaded from ${devtype}"

if test -e ${devtype} ${devnum} ${prefix}uEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}uEnv.txt
	env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=%SERIAL_CONSOLE%,%SERIAL_CONSOLE_SPEED% console=tty1"; fi
if test "${console}" = "serial"; then setenv consoleargs "console=%SERIAL_CONSOLE%,%SERIAL_CONSOLE_SPEED%"; fi

# get PARTUUID of first partition on SD/eMMC it was loaded from
# mmc 0 is always mapped to device u-boot (2016.09+) was loaded from
if test "${devtype}" = "mmc"; then part uuid mmc 0:1 partuuid; fi

setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} ${consoleargs} consoleblank=0 loglevel=${verbosity} ubootpart=${partuuid} usb-storage.quirks=${usbstoragequirks} ${extraargs} ${extraboardargs}"

load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}Image
fdt addr ${fdt_addr_r}
fdt resize 65536

if load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd; then
    booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r};
else
    booti ${kernel_addr_r} - ${fdt_addr_r};
fi

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
