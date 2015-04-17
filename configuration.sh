#!/bin/bash



CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS=" -j$(($CPUS + $CPUS/2)) ";



#---------------------------------------------
# environment
#---------------------------------------------
CWD=$(pwd)
BUILD="build"
SOURCE="source"
PKG="pkg"
OUTPUT="output"
TOOLS="tools"
FLASH="flash"



#---------------------------------------------
# resources
#---------------------------------------------
URL_LINUX_UPGRADE_TOOL="http://dl.radxa.com/rock/tools/linux"
LINUX_UPGRADE_TOOL="Linux_Upgrade_Tool_v1.21"
URL_XTOOLS_OLD="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7/"
URL_XTOOLS="http://archlinuxarm.org/builder/xtools/x-tools7h.tar.xz"
XTOOLS_OLD="x-tools7h_old"
XTOOLS="x-tools7h"
URL_RK2918_TOOLS="https://github.com/TeeFirefly/"
RK2918_TOOLS="rk2918_tools"
URL_RKFLASH_TOOLS="https://github.com/neo-technologies/"
RKFLASH_TOOLS="rkflashtool"
URL_MKBOOTIMG_TOOLS="https://github.com/neo-technologies/"
MKBOOTIMG_TOOLS="rockchip-mkbootimg"
URL_BOOT_LOADER_SOURCE="https://github.com/linux-rockchip/"
BOOT_LOADER="u-boot-rockchip"
BOOT_LOADER_CONFIG="rk3288_defconfig"
URL_FIRMWARE="https://github.com/rkchrome/overlay/archive/"
FIRMWARE="master.zip"
URL_LINUX_SOURCE="https://bitbucket.org/T-Firefly"
LINUX_SOURCE="firefly-rk3288-kernel"
LINUX_CONFIG="rk3288_config"
MODULES="mali_kbase gspca_main"
URL_ROOTFS="ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-devtools/minirootfs/roots"
ROOTFS="slack-current-miniroot_09Mar15"
ROOTFS_XFCE=$(echo $ROOTFS | sed 's#miniroot#xfce#')
URL_VIDEO_DRIVER="http://malideveloper.arm.com/downloads/drivers/binary/r5p0-06rel0/"
VIDEO_DRIVER="mali-t76x_r5p0-06rel0_linux_1+fbdev"
VERSION=$(date +%Y%m%d)
ROOT_DISK="mmcblk0p3"



#---------------------------------------------
# packages
#---------------------------------------------
URL_DISTR="http://dl.fail.pp.ua/slackware/slackwarearm-current/slackware"
_ARCH="arm"
_BUILD=1
_PACKAGER="mara"
CATEGORY_PKG="a ap l n x xfce"
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
     htop
     man
     man-page
     mc
     sqlite
     sudo'

l=' ConsoleKit
    GConf
    M2Crypto
    alsa-lib
    alsa-oss
    apr
    apr-util
    aspell
    aspell-en
    at-spi2-atk
    at-spi2-core
    atk
    audiofile
    boost
    cairo
    db42
    db44
    db48
    dbus-glib
    dconf
    desktop-file-utils
    djvulibre
    expat
    freetype
    gamin
    gdk-pixbuf2
    gegl
    giflib
    glade3
    glib-networking
    glib2
    glibc-i18n
    glibc-profile
    gmime
    gmm
    gmp
    gnome-icon-theme
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
    gtkspell
    gvfs
    harfbuzz
    hicolor-icon-theme
    icon-naming-utils
    icu4c
    ilmbase
    imlib
    iso-codes
    jasper
    keybinder
    keyutils
    lcms2
    libaio
    libao
    libarchive
    libart_lgpl
    libbluedevil
    libcaca
    libcanberra
    libcap
    libcroco
    libdiscid
    libdvdread
    libelf
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
    libsndfile
    libsoup
    libspectre
    libssh
    libtasn1
    libtermcap
    libtiff
    libunistring
    libusb
    libusb-compat
    libvorbis
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
    pango
    pcre
    polkit
    polkit-gnome
    poppler
    poppler-data
    readline
    sdl
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
    bluez-hcidump
    ca-certificates
    conntrack-tools
    cyrus-sasl
    gnutls
    iptables
    nettle
    p11-kit'

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
    glamor-egl
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
    liberation-fonts-ttf
    libevdev
    libfontenc
    libhangul
    libpciaccess
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
    xf86-video-modesetting
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
    libxfcegui4
    orage
    thunar-volman
    tumbler
    xfce4-appfinder
    xfce4-clipman-plugin
    xfce4-dev-tools
    xfce4-mixer
    xfce4-notifyd
    xfce4-panel
    xfce4-power-manager
    xfce4-screenshooter
    xfce4-session
    xfce4-settings
    xfce4-systemload-plugin
    xfce4-taskmanager
    xfce4-terminal
    xfce4-volumed
    xfce4-weather-plugin
    xfconf
    xfdesktop
    xfwm4
    xfwm4-themes'



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
    #rm -rf ${CWD}/$BUILD/{$SOURCE/{$XTOOLS,$XTOOLS_OLD},$PKG,$OUTPUT/{$TOOLS,$FLASH}}
    rm -rf ${CWD}/$BUILD/ || exit 1
}

prepare_dest (){
    mkdir -p ${CWD}/$BUILD/{$SOURCE/$XTOOLS,$PKG,$OUTPUT/{$TOOLS,$FLASH}} || exit 1
}



