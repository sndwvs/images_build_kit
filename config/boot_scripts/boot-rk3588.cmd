# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x9000000"
setenv overlay_error "false"
# default values
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv console "both"
setenv rootfstype "ext4"
setenv earlycon "off"

echo "Boot script loaded from ${devtype} ${devnum}"

if load ${devtype} ${devnum} ${load_addr} ${prefix}uEnv.txt; then
    env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=tty1"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "console=%SERIAL_CONSOLE%,%SERIAL_CONSOLE_SPEED%n8 ${consoleargs}"; fi
if test "${earlycon}" = "on"; then setenv consoleargs "earlycon ${consoleargs}"; fi

setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} init=/sbin/init ${consoleargs} consoleblank=0 loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} ${extraargs}"

load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}Image
fdt addr ${fdt_addr_r}
fdt resize 65536

# read "/chosen" node, property "bootargs", and store in var "dtb_bootargs"
fdt get value dtb_bootargs /chosen bootargs
if test "${dtb_bootargs}" != "" ; then setenv bootargs "${bootargs} ${dtb_bootargs}"; fi

for overlay_file in ${overlays}; do
    if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/rockchip/overlay/${overlay_file}.dtbo; then
        echo "Applying kernel provided DT overlay ${overlay_file}.dtbo"
        fdt apply ${load_addr} || setenv overlay_error "true"
    fi
done

if test "${overlay_error}" = "true"; then
    echo "Error applying DT overlays, restoring original DT"
    load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
else
    if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/rockchip/overlay/${overlay_prefix}-fixup.scr; then
        echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
        source ${load_addr}
    fi
    if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
        load ${devtype} ${devnum} ${load_addr} ${prefix}fixup.scr
        echo "Applying user provided fixup script (fixup.scr)"
        source ${load_addr}
    fi
fi

if load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd; then
    booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r};
else
    booti ${kernel_addr_r} - ${fdt_addr_r};
fi

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
