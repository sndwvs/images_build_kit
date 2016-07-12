if ext4load mmc 0 0x00000000 /boot/.verbose
then
setenv verbosity 8
else
setenv verbosity 1
fi
setenv bootargs 'console=ttyS0,115200 console=tty1 earlyprintk root=/dev/mmcblk0p1 ro rootwait rootfstype=ext4 sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=16 hdmi.audio=EDID:0 disp.screen0_output_mode=1920x1080p60 panic=10 consoleblank=0 enforcing=0 loglevel=${verbosity}'
#--------------------------------------------------------------------------------------------------------------------------------
# Boot loader script to boot with different boot methods for old and new kernel
#--------------------------------------------------------------------------------------------------------------------------------
if ext4load mmc 0 0x00000000 /boot/.next
then
# sunxi mainline kernel
#--------------------------------------------------------------------------------------------------------------------------------
ext4load mmc 0 ${fdt_addr_r} /boot/dtb/${fdtfile}
ext4load mmc 0 ${kernel_addr_r} /boot/zImage
env set fdt_high ffffffff
bootz ${kernel_addr_r} - ${fdt_addr_r}
#--------------------------------------------------------------------------------------------------------------------------------
else
# sunxi legacy kernel
#--------------------------------------------------------------------------------------------------------------------------------
ext4load mmc 0 ${fdt_addr_r} /boot/script.bin
ext4load mmc 0 ${kernel_addr_r} /boot/zImage
bootz ${kernel_addr_r}
#--------------------------------------------------------------------------------------------------------------------------------
fi
# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
