# DO NOT EDIT THIS FILE
#
# Please edit /boot/uEnv.txt to set supported parameters
#

setenv load_addr "0x32000000"
setenv kernel_addr_r "0x34000000"
setenv fdt_addr_r "0x4080000"
setenv overlay_error "false"
# default values
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv console "both"
setenv rootfstype "ext4"




# odroid c4 legacy kernel values from boot.ini

setenv dtb_loadaddr "0x1000000"
setenv k_addr "0x1100000"
setenv loadaddr "0x1B00000"
setenv initrd_loadaddr "0x4080000"

setenv display_autodetect "true"
# HDMI Mode
# Resolution Configuration
#    Symbol             | Resolution
# ----------------------+-------------
#    "480x272p60hz"     | 480x272 Progressive 60Hz
#    "480x320p60hz"     | 480x320 Progressive 60Hz
#    "480p60hz"         | 720x480 Progressive 60Hz
#    "576p50hz"         | 720x576 Progressive 50Hz
#    "720p60hz"         | 1280x720 Progressive 60Hz
#    "720p50hz"         | 1280x720 Progressive 50Hz
#    "1080p60hz"        | 1920x1080 Progressive 60Hz
#    "1080p50hz"        | 1920x1080 Progressive 50Hz
#    "1080p30hz"        | 1920x1080 Progressive 30Hz
#    "1080p24hz"        | 1920x1080 Progressive 24Hz
#    "1080i60hz"        | 1920x1080 Interlaced 60Hz
#    "1080i50hz"        | 1920x1080 Interlaced 50Hz
#    "2160p60hz"        | 3840x2160 Progressive 60Hz
#    "2160p50hz"        | 3840x2160 Progressive 50Hz
#    "2160p30hz"        | 3840x2160 Progressive 30Hz
#    "2160p25hz"        | 3840x2160 Progressive 25Hz
#    "2160p24hz"        | 3840x2160 Progressive 24Hz
#    "smpte24hz"        | 3840x2160 Progressive 24Hz SMPTE
#    "2160p60hz420"     | 3840x2160 Progressive 60Hz YCbCr 4:2:0
#    "2160p50hz420"     | 3840x2160 Progressive 50Hz YCbCr 4:2:0
#    "640x480p60hz"     | 640x480 Progressive 60Hz
#    "800x480p60hz"     | 800x480 Progressive 60Hz
#    "800x600p60hz"     | 800x600 Progressive 60Hz
#    "1024x600p60hz"    | 1024x600 Progressive 60Hz
#    "1024x768p60hz"    | 1024x768 Progressive 60Hz
#    "1280x800p60hz"    | 1280x800 Progressive 60Hz
#    "1280x1024p60hz"   | 1280x1024 Progressive 60Hz
#    "1360x768p60hz"    | 1360x768 Progressive 60Hz
#    "1440x900p60hz"    | 1440x900 Progressive 60Hz
#    "1600x900p60hz"    | 1600x900 Progressive 60Hz
#    "1600x1200p60hz"   | 1600x1200 Progressive 60Hz
#    "1680x1050p60hz"   | 1680x1050 Progressive 60Hz
#    "1920x1200p60hz"   | 1920x1200 Progressive 60Hz
#    "2560x1080p60hz"   | 2560x1080 Progressive 60Hz
#    "2560x1440p60hz"   | 2560x1440 Progressive 60Hz
#    "2560x1600p60hz"   | 2560x1600 Progressive 60Hz
#    "3440x1440p60hz"   | 3440x1440 Progressive 60Hz
setenv hdmimode "1080p60hz"
setenv monitor_onoff "false"
setenv overscan "100"
setenv sdrmode "auto"
setenv voutmode "hdmi"
setenv disablehpd "false"
setenv cec "false"
setenv disable_vu7 "true"
setenv max_freq_a55 "1908"
#setenv max_freq_a55 "2100"
setenv maxcpus "4"

# legacy kernel values from boot.ini




if test -e ${devtype} ${devnum} ${prefix}uEnv.txt; then
    load ${devtype} ${devnum} ${load_addr} ${prefix}uEnv.txt
    env import -t ${load_addr} ${filesize}
fi

if test "${kernel}" = "legacy"; then
    # legacy kernel

    if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=ttyS0,%SERIAL_CONSOLE_SPEED%"; fi
    if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} console=tty1"; fi

    setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} init=/sbin/init ${consoleargs} consoleblank=0 coherent_pool=2M loglevel=${verbosity} ${amlogic} no_console_suspend fsck.repair=yes net.ifnames=0 elevator=noop hdmimode=${hdmimode} cvbsmode=576cvbs max_freq_a55=${max_freq_a55} maxcpus=${maxcpus} voutmode=${voutmode} ${cmode} disablehpd=${disablehpd} cvbscable=${cvbscable} overscan=${overscan} ${hid_quirks} monitor_onoff=${monitor_onoff} ${cec_enable} sdrmode=${sdrmode}"
    echo "Legacy bootargs: ${bootargs}"

#    load ${devtype} ${devnum} ${k_addr} boot/zImage
    load ${devtype} ${devnum} ${loadaddr} ${prefix}Image
    load ${devtype} ${devnum} ${dtb_loadaddr} ${prefix}dtb/${fdtfile}
    fdt addr ${dtb_loadaddr}
#    unzip ${k_addr} ${loadaddr}

    for overlay_file in ${overlays}; do
        if load ${devtype} ${devnum} ${loadaddr} ${prefix}dtb/amlogic/overlay/${overlay_file}.dtbo; then
            echo "Applying kernel provided DT overlay ${overlay_file}.dtbo"
            fdt apply ${loadaddr} || setenv overlay_error "true"
        fi
    done

    if test "${overlay_error}" = "true"; then
        echo "Error applying DT overlays, restoring original DT"
        load ${devtype} ${devnum} ${dtb_loadaddr} ${prefix}dtb/${fdtfile}
    else
        if load ${devtype} ${devnum} ${loadaddr} ${prefix}dtb/amlogic/overlay/${overlay_prefix}-fixup.scr; then
            echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
            source ${loadaddr}
        fi
        if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
            load ${devtype} ${devnum} ${loadaddr} ${prefix}fixup.scr
            echo "Applying user provided fixup script (fixup.scr)"
            source ${loadaddr}
        fi
    fi

    if load ${devtype} ${devnum} ${initrd_loadaddr} ${prefix}uInitrd; then
        booti ${loadaddr} ${initrd_loadaddr} ${dtb_loadaddr};
    else
        booti ${loadaddr} - ${dtb_loadaddr};
    fi
else
    # next kernel

    if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=ttyAML0,%SERIAL_CONSOLE_SPEED%n8"; fi
    if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} console=tty1"; fi

    setenv bootargs "root=${rootdev} ro rootwait rootfstype=${rootfstype} init=/sbin/init ${consoleargs} consoleblank=0 coherent_pool=2M loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} ${extraargs} ${extraboardargs}"

    load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
    load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}Image
    fdt addr ${fdt_addr_r}
    fdt resize 65536

    # read "/chosen" node, property "bootargs", and store in var "dtb_bootargs"
    fdt get value dtb_bootargs /chosen bootargs
    if test "${dtb_bootargs}" != "" ; then setenv bootargs "${bootargs} ${dtb_bootargs}"; fi

    echo "Mainline bootargs: ${bootargs}"

    for overlay_file in ${overlays}; do
        if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/amlogic/overlay/${overlay_file}.dtbo; then
            echo "Applying kernel provided DT overlay ${overlay_file}.dtbo"
            fdt apply ${load_addr} || setenv overlay_error "true"
        fi
    done

    if test "${overlay_error}" = "true"; then
        echo "Error applying DT overlays, restoring original DT"
        load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
    else
        if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/amlogic/overlay/${overlay_prefix}-fixup.scr; then
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
fi

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
