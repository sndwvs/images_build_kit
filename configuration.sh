#!/bin/bash



CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS=" -j$(($CPUS + $CPUS/2)) ";



#---------------------------------------------
# environment
#---------------------------------------------
PWD=$(pwd)
BUILD="build"
SOURCE="source"
PKG="pkg"
OUTPUT="output"
TOOLS="tools"
FLASH="flash"
LOG="build.log"


#---------------------------------------------
# firefly
#---------------------------------------------
if [ "$BOARD_NAME" = "firefly" ]; then
    URL_XTOOLS_OLD="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6/"
    XTOOLS_OLD="x-tools7h_old"
    URL_LINUX_UPGRADE_TOOL="http://dl.radxa.com/rock/tools/linux"
    LINUX_UPGRADE_TOOL="Linux_Upgrade_Tool_v1.21"
    URL_RK2918_TOOLS="https://github.com/TeeFirefly/"
    RK2918_TOOLS="rk2918_tools"
    URL_RKFLASH_TOOLS="https://github.com/neo-technologies/"
    RKFLASH_TOOLS="rkflashtool"
    URL_MKBOOTIMG_TOOLS="https://github.com/neo-technologies/"
    MKBOOTIMG_TOOLS="rockchip-mkbootimg"
    URL_BOOT_LOADER_SOURCE="https://github.com/linux-rockchip"
    BOOT_LOADER="u-boot-rockchip"
    BOOT_LOADER_CONFIG="rk3288_defconfig"
    URL_FIRMWARE="https://github.com/rkchrome/overlay/archive/"
    FIRMWARE="master.zip"
    URL_LINUX_SOURCE="https://bitbucket.org/T-Firefly"
    LINUX_SOURCE="firefly-rk3288-kernel"
    LINUX_CONFIG="rk3288_config"
    MODULES="mali_kbase gspca_main"
    ROOT_DISK="mmcblk0p3"
    if [[ $KERNEL_SOURCE == "next" ]];then
        # Vanilla Linux  
        URL_LINUX_SOURCE="https://github.com/mmind/"
        LINUX_SOURCE="linux-rockchip"
        BARANCH="remotes/origin/devel/somewhat-stable"
        LINUX_SOURCE_VERSION="https://raw.githubusercontent.com/mmind/linux-rockchip/devel/somewhat-stable/Makefile"  
        LINUX_CONFIG="linux-firefly-next.config" #original rk3288_veyron_defconfig
        MODULES=""
        BOOT_LOADER_CONFIG="firefly-rk3288_defconfig"
        ROOT_DISK="mmcblk0p1"     
    fi    
fi
#---------------------------------------------


#---------------------------------------------
# get version linux source
#---------------------------------------------
kernel_version KERNEL_VERSION


#---------------------------------------------
# cubietruck
#---------------------------------------------
if [ "$BOARD_NAME" == "cubietruck" ]; then
    URL_SUNXI_TOOLS="https://github.com/linux-sunxi"
    SUNXI_TOOLS="sunxi-tools"
    SUNXI_TOOLS_VERSION="v1.2"
    URL_FIRMWARE="https://github.com/igorpecovnik/lib/raw/next/bin"
    FIRMWARE="ap6210.zip"
    FIRMWARE1="linux-firmware.zip"
    URL_LINUX_SOURCE="https://github.com/dan-and"
    LINUX_SOURCE="linux-sunxi"
    URL_LINUX_CONFIG_SOURCE="https://github.com/igorpecovnik/lib/raw/next/config"
    LINUX_CONFIG="linux-sunxi.config"
    BOOT_LOADER_CONFIG="Cubietruck_config"
    BOOT_LOADER_BIN="u-boot-sunxi-with-spl.bin"
    MODULES="hci_uart gpio_sunxi bt_gpio wifi_gpio rfcomm hidp sunxi-ir bonding spi_sun7i bcmdhd ump mali mali_drm"
    if [[ $KERNEL_SOURCE == "next" ]];then
        # Vanilla Linux
        URL_LINUX_SOURCE="http://mirror.yandex.ru/pub/linux/kernel/v4.x"
        LINUX_SOURCE="linux-$KERNEL_VERSION"  
        LINUX_CONFIG="linux-sunxi-next.config"
        FIRMWARE=""
        MODULES="brcmfmac rfcomm hidp bonding"
    fi
    ROOT_DISK="mmcblk0p1"
fi
#---------------------------------------------


URL_BOOT_LOADER_SOURCE="http://git.denx.de"
BOOT_LOADER="u-boot"
BOOT_LOADER_VERSION="" #>v2016.03
XTOOLS="x-tools7h"
URL_XTOOLS="http://archlinuxarm.org/builder/xtools/$XTOOLS.tar.xz"
URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots/"
ROOTFS_NAME=$(wget -q -O - $URL_ROOTFS | grep -oP "(slack-current[\.\-\+\d\w]+.tar.xz)" | head -n1 | cut -d '.' -f1)
VERSION=$(date +%Y%m%d)
ROOTFS="$ROOTFS_NAME-$KERNEL_VERSION-$BOARD_NAME-build-$VERSION"
ROOTFS_XFCE="$(echo $ROOTFS_NAME | sed 's#miniroot#xfce#')-$KERNEL_VERSION-$BOARD_NAME-build-$VERSION"


#---------------------------------------------
# packages
#---------------------------------------------
URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-current/slackware"
_ARCH="arm"
_BUILD=1
_PACKAGER="mara"
CATEGORY_PKG="a ap d l n x xfce"
a=' acpid
    cpio
    gpm
    logrotate
    mkinitrd
    openssl-solibs
    patch
    pkgtools
    slocate
    sysfsutils
    sysklogd
    sysvinit-functions
    udisks
    udisks2
    upower
    usbutils
    utempter'

ap=' alsa-utils
     groff
     flac
     htop
     man
     man-pages
     mc
     mpg123
     pamixer
     cgmanager
     sqlite
     sudo'

d=' binutils
    llvm'

l=' ConsoleKit2
    GConf
    M2Crypto
    aalib
    a52dec
    alsa-lib
    alsa-oss
    alsa-plugins
    apr
    apr-util
    aspell
    aspell-en
    at-spi2-atk
    at-spi2-core
    atk
    atkmm
    audiofile
    boost
    cairo
    cairomm
    db42
    db44
    db48
    dbus-glib
    dconf
    desktop-file-utils
    djvulibre
    elfutils
    esound
    expat
    freetype
    fribidi
    gamin
    gdk-pixbuf2
    gegl
    giflib
    glade3
    glib-networking
    glib2
    glibc-i18n
    glibc-profile
    glibmm
    gmime
    gmm
    gmp
    adwaita-icon-theme
    gnome-keyring
    gnome-themes-standard
    gobject-introspection
    gsettings-desktop-schemas
    gst-plugins-base
    gst-plugins-good
    gstreamer
    gtk+
    gtk+2
    gtk+3
    gtkmm2
    gtkmm3
    gtkspell
    gvfs
    harfbuzz
    hicolor-icon-theme
    icon-naming-utils
    icu4c
    ilmbase
    iso-codes
    jasper
    json-c
    keybinder
    keyutils
    lcms2
    libaio
    libao
    libarchive
    libart_lgpl
    libasyncns
    libbluedevil
    libcaca
    libcanberra
    libcap
    libcdio
    libcdio-paranoia
    libcroco
    libdiscid
    libdvdnav
    libdvdread
    libevent
    libexif
    libffi
    libglade
    libgnome-keyring
    libgphoto2
    libgpod
    libgsf
    libical
    libid3tag
    libidl
    libidn
    libjpeg
    libmad
    libmcrypt
    libmcs
    libmng
    libmowgli
    libmpc
    libmsn
    libmtp
    libnih
    libnjb
    libnl
    libnl3
    libnotify
    libogg
    liboggz
    liboil
    libplist
    libpng
    libproxy
    librsvg
    libsamplerate
    libsecret
    libsigc++
    libsndfile
    libsoup
    libspectre
    libssh
    libtasn1
    libtermcap
    libtiff
    libtheora
    libunistring
    libusb
    libusb-compat
    libvorbis
    libvpx
    libwmf
    libwmf-docs
    libwnck
    libwpd
    libxklavier
    libxml2
    libxslt
    libyaml
    libzip
    loudmouth
    lzo
    mhash
    mm
    mozilla-nss
    mpfr
    ncurses
    openjpeg
    pango
    pangomm
    pcre
    polkit
    polkit-gnome
    poppler
    poppler-data
    pulseaudio
    readline
    sdl
    speexdsp
    shared-desktop-ontologies
    shared-mime-info
    slang
    sound-theme-freedesktop
    startup-notification
    svgalib
    tango-icon-theme
    tango-icon-theme-extras
    v4l-utils
    vte
    zlib'

n=' bluez
    bluez-firmware
    ca-certificates
    conntrack-tools
    cyrus-sasl
    gnutls
    iptables
    nettle
    openssl
    p11-kit
    samba'

x=' anthy
    appres
    bdftopcf
    beforelight
    bigreqsproto
    bitmap
    compiz
    compositeproto
    damageproto
    dejavu-fonts-ttf
    dmxproto
    dri2proto
    dri3proto
    editres
    encodings
    evieext
    fixesproto
    font-adobe-100dpi
    font-adobe-75dpi
    font-adobe-utopia-100dpi
    font-adobe-utopia-75dpi
    font-adobe-utopia-type1
    font-alias
    font-arabic-misc
    font-bh-100dpi
    font-bh-75dpi
    font-bh-lucidatypewriter-100dpi
    font-bh-lucidatypewriter-75dpi
    font-bh-ttf
    font-bh-type1
    font-bitstream-100dpi
    font-bitstream-75dpi
    font-bitstream-speedo
    font-bitstream-type1
    font-cronyx-cyrillic
    font-cursor-misc
    font-daewoo-misc
    font-dec-misc
    font-ibm-type1
    font-isas-misc
    font-jis-misc
    font-micro-misc
    font-misc-cyrillic
    font-misc-ethiopic
    font-misc-meltho
    font-misc-misc
    font-mutt-misc
    font-schumacher-misc
    font-screen-cyrillic
    font-sony-misc
    font-sun-misc
    font-util
    font-winitzki-cyrillic
    font-xfree86-type1
    fontcacheproto
    fontconfig
    fontsproto
    fonttosfnt
    freeglut
    fslsfonts
    fstobdf
    gccmakedep
    glew
    glproto
    glu
    iceauth
    ico
    imake
    inputproto
    kbproto
    libFS
    libICE
    libSM
    libX11
    libXaw3dXft
    libXScrnSaver
    libXau
    libXaw
    libXaw3d
    libXcm
    libXcomposite
    libXcursor
    libXdamage
    libXdmcp
    libXevie
    libXext
    libXfixes
    libXfont
    libXfontcache
    libXft
    libXi
    libXinerama
    libXmu
    libXp
    libXpm
    libXpresent
    libXrandr
    libXrender
    libXres
    libXt
    libXtst
    libXv
    libXvMC
    libXxf86dga
    libXxf86misc
    libXxf86vm
    libdmx
    libdrm
    libepoxy
    liberation-fonts-ttf
    libevdev
    libfontenc
    libhangul
    libpciaccess
    libva
    libpthread-stubs
    libvdpau
    libxcb
    libxkbfile
    libxshmfence
    listres
    lndir
    luit
    m17n-lib
    makedepend
    mesa
    mkcomposecache
    mkfontdir
    mkfontscale
    motif
    mtdev
    pixman
    presentproto
    printproto
    randrproto
    recordproto
    rendercheck
    renderproto
    resourceproto
    rgb
    sazanami-fonts-ttf
    scim
    scim-anthy
    scim-hangul
    scim-input-pad
    scim-m17n
    scim-pinyin
    scim-tables
    scrnsaverproto
    sessreg
    setxkbmap
    showfont
    sinhala_lklug-font-ttf
    smproxy
    tibmachuni-font-ttf
    transset
    ttf-indic-fonts
    twm
    util-macros
    videoproto
    viewres
    wqy-zenhei-font-ttf
    x11-skel
    x11perf
    xauth
    xbacklight
    xbiff
    xbitmaps
    xcb-proto
    xcb-util
    xcb-util-cursor
    xcb-util-errors
    xcb-util-image
    xcb-util-keysyms
    xcb-util-renderutil
    xcb-util-wm
    xcm
    xcmiscproto
    xcmsdb
    xcompmgr
    xconsole
    xcursor-themes
    xcursorgen
    xdbedizzy
    xdg-user-dirs
    xdg-utils
    xditview
    xdm
    xdpyinfo
    xdriinfo
    xev
    xextproto
    xf86-input-evdev
    xf86-input-keyboard
    xf86-input-mouse
    xf86-video-fbdev
    xf86-video-v4l
    xf86bigfontproto
    xf86dga
    xf86dgaproto
    xf86driproto
    xf86miscproto
    xf86vidmodeproto
    xfd
    xfontsel
    xfs
    xfsinfo
    xgamma
    xgc
    xhost
    xineramaproto
    xinit
    xinput
    xkbcomp
    xkbevd
    xkbprint
    xkbutils
    xkeyboard-config
    xlsatoms
    xlsclients
    xlsfonts
    xmag
    xmh
    xmodmap
    xorg-cf-files
    xorg-docs
    xorg-server
    xorg-server-xephyr
    xorg-server-xnest
    xorg-server-xvfb
    xorg-sgml-doctools
    xpr
    xprop
    xproto
    xpyb
    xrandr
    xrdb
    xrefresh
    xscope
    xset
    xsetroot
    xsm
    xstdcmap
    xterm
    xtrans
    xvidtune
    xvinfo
    xwd
    xwininfo
    xwud'
xfce=' Thunar
    exo
    garcon
    gtk-xfce-engine
    libxfce4ui
    libxfce4util
    orage
    thunar-volman
    tumbler
    xfce4-appfinder
    xfce4-clipman-plugin
    xfce4-dev-tools
    xfce4-pulseaudio-plugin
    xfce4-notifyd
    xfce4-panel
    xfce4-power-manager
    xfce4-screenshooter
    xfce4-session
    xfce4-settings
    xfce4-systemload-plugin
    xfce4-taskmanager
    xfce4-terminal
    xfce4-weather-plugin
    xfconf
    xfdesktop
    xfwm4'

URL_DISTR_EXTRA="http://dl.fail.pp.ua/slackware/pkg/arm"
x_extra_firefly='   xf86-video-armsoc-rockchip
                    firefly-libgl'



patching_kernel_sources (){
#--------------------------------------------------------------------------------------------------------------------------------
# patching kernel sources
#--------------------------------------------------------------------------------------------------------------------------------
    message "" "patching" "kernel $LINUX_SOURCE"

    cd $CWD/$BUILD/$SOURCE/$LINUX_SOURCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1

    if [[ "$BOARD_NAME" == "cubietruck" ]];then
        # mainline
        if [[ "$KERNEL_SOURCE" == "next" ]];then
            #   [ 11.822938] eth0: device MAC address 86:d7:74:ee:31:69
            #   [ 11.828080] libphy: PHY stmmac-0:ffffffff not found
            #   [ 11.832956] eth0: Could not attach to PHY
            #   [ 11.836963] stmmac_open: Cannot attach to PHY (error: -19)
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch || exit 1
            fi

            # sun4i: spi: Allow transfers larger than FIFO size
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/03_spi_allow_transfer_larger.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/03_spi_allow_transfer_larger.patch || exit 1
            fi

            # fix BRCMFMAC AP mode Banana & CT
#            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/brcmfmac_ap_banana_ct.patch | grep Reversed)" == "" ]; then
#                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/brcmfmac_ap_banana_ct.patch || exit 1
#            fi

            # fix BRCMF and MMC if copy big data to WIFI
            # http://forum.armbian.com/index.php/topic/230-cubietruck-armbian-42-cubietruck-debian-jessie-416-wifi-does-not-work/
            # https://groups.google.com/forum/#!msg/linux-sunxi/v6Ktt8lAnw0/T9gOChygom0J
#            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/brcmf_mmc_copy_big_data.patch | grep Reversed)" == "" ]; then
#                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/brcmf_mmc_copy_big_data.patch || exit 1
#            fi
        else
        # sunxi 3.4
        #   rm $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/drivers/spi/spi-sun7i.c
        #   rm -r $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/drivers/net/wireless/ap6210/

            # SPI functionality
                if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/spi.patch | grep previ)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/spi.patch || exit 1
            fi

            # Aufs3
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/linux-sunxi-3.4.108-overlayfs.patch | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/linux-sunxi-3.4.108-overlayfs.patch || exit 1
            fi

            # More I2S and Spdif
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/i2s_spdif_sunxi.patch | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/i2s_spdif_sunxi.patch || exit 1
            fi

            # A fix for rt8192
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/rt8192cu-missing-case.patch | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/rt8192cu-missing-case.patch || exit 1
            fi

            # Upgrade to 3.4.109"
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/patch-3.4.108-109 | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/patch-3.4.108-109 || exit 1
            fi
        fi
    elif [[ "$BOARD_NAME" == "firefly" ]];then
        if [[ "$KERNEL_SOURCE" == "next" ]];then
            #   [ 11.822938] eth0: device MAC address 86:d7:74:ee:31:69
            #   [ 11.828080] libphy: PHY stmmac-0:ffffffff not found
            #   [ 11.832956] eth0: Could not attach to PHY
            #   [ 11.836963] stmmac_open: Cannot attach to PHY (error: -19)
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/01_fix_tx_normaldesc.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/01_fix_tx_normaldesc.patch || exit 1
            fi

            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch || exit 1
            fi

#            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/03_dts_remove_broken-cd_from_emmc_and_sdio.patch | grep Reversed)" == "" ]; then
#                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/03_dts_remove_broken-cd_from_emmc_and_sdio.patch || exit 1
#            fi
            # The rtc hym8563 maybe failed to register if first startup or rtc
            # powerdown:
            # [    0.988540 ] rtc-hym8563 1-0051: no valid clock/calendar values available
            # [    0.995642 ] rtc-hym8563 1-0051: rtc core: registered hym8563 as rtc0
            # [    1.078985 ] rtc-hym8563 1-0051: no valid clock/calendar values available
            # [    1.085698 ] rtc-hym8563 1-0051: hctosys: unable to read the hardware clock
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/04_rtc_hym8563_make_sure_hym8563_can_be_normal_work.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/04_rtc_hym8563_make_sure_hym8563_can_be_normal_work.patch || exit 1
            fi
        fi
    fi
}


#---------------------------------------------
# patch the kernel configuration
#---------------------------------------------
patching_kernel_config (){
    message "" "patching" "kernel config $LINUX_CONFIG"
    if [ "$(patch --dry-run -t -p1 < $CWD/patch/linux-fitefly-rk3288.config.patch | grep Reversed)" == "" ]; then
        patch --batch -f -p1 < $CWD/patch/linux-fitefly-rk3288.config.patch  || exit 1
    fi
}



#---------------------------------------------
# croos compilation
#---------------------------------------------
export PATH=$PATH:$CWD/$BUILD/${SOURCE}/$XTOOLS_OLD/bin:$CWD/$BUILD/${SOURCE}/$XTOOLS/arm-unknown-linux-gnueabihf/bin:$CWD/$BUILD/$OUTPUT/$TOOLS/
CROSS_OLD="arm-eabi-"
CROSS="arm-unknown-linux-gnueabihf-"



#---------------------------------------------
# create dir
#---------------------------------------------
clean_sources (){
    #rm -rf $CWD/$BUILD/{$SOURCE/{$XTOOLS,$XTOOLS_OLD},$PKG,$OUTPUT/{$TOOLS,$FLASH}}
    rm -rf $CWD/$BUILD/ || exit 1
}

prepare_dest (){
    mkdir -p $CWD/$BUILD/{$SOURCE/$XTOOLS,$PKG,$OUTPUT/{$TOOLS,$FLASH}} || exit 1
    reset
}



