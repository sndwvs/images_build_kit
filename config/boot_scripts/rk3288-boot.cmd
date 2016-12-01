if ext4load mmc 1 0x00000000 /boot/.verbose
then
setenv verbosity 8
else
setenv verbosity 1
fi
setenv bootargs 'console=ttyS2,115200n8 console=tty1 earlyprintk root=/dev/mmcblk2p1 ro rootwait rootfstype=ext4 init=/sbin/init loglevel=${verbosity}'
#--------------------------------------------------------------------------------------------------------------------------------
# Boot loader script to boot with different boot methods for old and new kernel
#--------------------------------------------------------------------------------------------------------------------------------
#if ext4load mmc 0 0x00000000 /boot/.next
#then
# rockchip mainline kernel
#--------------------------------------------------------------------------------------------------------------------------------
#ext4load mmc 1 ${fdt_addr_r} /boot/dtb/${fdtfile}
ext4load mmc 1 ${fdt_addr_r} /boot/dtb/rk3288-firefly.dtb
ext4load mmc 1 ${kernel_addr_r} /boot/zImage
env set fdt_high 0x1fffffff
bootz ${kernel_addr_r} - ${fdt_addr_r}
#--------------------------------------------------------------------------------------------------------------------------------
#else
# rockchip legacy kernel
#--------------------------------------------------------------------------------------------------------------------------------
#ext4load mmc 0 ${fdt_addr_r} /boot/script.bin
#ext4load mmc 0 ${kernel_addr_r} /boot/zImage
#bootz ${kernel_addr_r}
#--------------------------------------------------------------------------------------------------------------------------------
#fi
# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
