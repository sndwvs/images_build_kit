# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x44000000"
# default values
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv console "both"
setenv disp_mem_reserves "off"
setenv disp_mode "1920x1080p60"
setenv rootfstype "ext4"

# Print boot source
itest.b *0x28 == 0x00 && echo "U-boot loaded from SD"
itest.b *0x28 == 0x02 && echo "U-boot loaded from eMMC or secondary SD"
itest.b *0x28 == 0x03 && echo "U-boot loaded from SPI"

echo "Boot script loaded from ${devtype}"

if test -e ${devtype} ${devnum} ${load_addr} ${prefix}uEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}uEnv.txt
	env import -t ${load_addr} ${filesize}
fi

if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=ttyS0,115200"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} earlyprintk console=tty1"; fi

# get PARTUUID of first partition on SD/eMMC it was loaded from
# mmc 0 is always mapped to device u-boot (2016.09+) was loaded from
if test "${devtype}" = "mmc"; then part uuid mmc 0:1 partuuid; fi

setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} ${consoleargs} hdmi.audio=EDID:0 disp.screen0_output_mode=${disp_mode} panic=10 consoleblank=0 loglevel=${verbosity} ubootpart=${partuuid} ubootsource=${devtype} ${extraargs} ${extraboardargs}"

if test "${disp_mem_reserves}" = "off"; then setenv bootargs "${bootargs} sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_fb_mem_reserve=16"; fi

load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}zImage

if test -e ${devtype} ${devnum} "${prefix}.next"; then
	echo "Found mainline kernel configuration"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
	fdt addr ${fdt_addr_r}
	fdt resize
	bootz ${kernel_addr_r} - ${fdt_addr_r}
else
	echo "Found legacy kernel configuration"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}script.bin
	bootz ${kernel_addr_r}
fi

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
