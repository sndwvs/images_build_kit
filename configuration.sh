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
     flac
     htop
     man
     man-page
     mc
     mpg123
     sqlite
     sudo'

l=' ConsoleKit
    GConf
    M2Crypto
    aalib
    a52dec
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
    gtkspell
    gvfs
    harfbuzz
    hicolor-icon-theme
    icon-naming-utils
    icu4c
    ilmbase
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
    libcdio
    libcdio-paranoia
    libcroco
    libdiscid
    libdvdnav
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
    xfwm4'



#---------------------------------------------
# patch the kernel configuration
#---------------------------------------------
KERNEL_CONFIG_PATCH='--- .config.orig	2015-04-18 15:10:10.201084928 +0300
+++ .config	2015-04-19 12:55:56.934205818 +0300
@@ -119,11 +119,8 @@
 CONFIG_NAMESPACES=y
 # CONFIG_UTS_NS is not set
 # CONFIG_IPC_NS is not set
-# CONFIG_USER_NS is not set
 # CONFIG_PID_NS is not set
 CONFIG_NET_NS=y
-CONFIG_UIDGID_CONVERTED=y
-# CONFIG_UIDGID_STRICT_TYPE_CHECKS is not set
 # CONFIG_SCHED_AUTOGROUP is not set
 # CONFIG_SYSFS_DEPRECATED is not set
 CONFIG_RELAY=y
@@ -3285,20 +3282,35 @@
 # CONFIG_JBD2_DEBUG is not set
 CONFIG_FS_MBCACHE=y
 # CONFIG_REISERFS_FS is not set
-# CONFIG_JFS_FS is not set
-# CONFIG_XFS_FS is not set
+CONFIG_JFS_FS=y
+CONFIG_JFS_POSIX_ACL=y
+CONFIG_JFS_SECURITY=y
+# CONFIG_JFS_DEBUG is not set
+# CONFIG_JFS_STATISTICS is not set
+CONFIG_XFS_FS=y
+CONFIG_XFS_QUOTA=y
+CONFIG_XFS_POSIX_ACL=y
+CONFIG_XFS_RT=y
+# CONFIG_XFS_WARN is not set
+# CONFIG_XFS_DEBUG is not set
 # CONFIG_GFS2_FS is not set
 # CONFIG_OCFS2_FS is not set
-# CONFIG_BTRFS_FS is not set
+CONFIG_BTRFS_FS=y
+CONFIG_BTRFS_FS_POSIX_ACL=y
+# CONFIG_BTRFS_FS_CHECK_INTEGRITY is not set
+CONFIG_BTRFS_FS_RUN_SANITY_TESTS=y
+# CONFIG_BTRFS_DEBUG is not set
 # CONFIG_NILFS2_FS is not set
 CONFIG_FS_POSIX_ACL=y
+CONFIG_EXPORTFS=y
 CONFIG_FILE_LOCKING=y
 CONFIG_FSNOTIFY=y
 CONFIG_DNOTIFY=y
 CONFIG_INOTIFY_USER=y
 # CONFIG_FANOTIFY is not set
 # CONFIG_QUOTA is not set
-# CONFIG_QUOTACTL is not set
+# CONFIG_QUOTA_NETLINK_INTERFACE is not set
+CONFIG_QUOTACTL=y
 # CONFIG_AUTOFS4_FS is not set
 CONFIG_FUSE_FS=y
 # CONFIG_CUSE is not set
@@ -3342,8 +3354,33 @@
 CONFIG_CONFIGFS_FS=y
 # CONFIG_MISC_FILESYSTEMS is not set
 CONFIG_NETWORK_FILESYSTEMS=y
-# CONFIG_NFS_FS is not set
-# CONFIG_NFSD is not set
+CONFIG_NFS_FS=y
+# CONFIG_NFS_V2 is not set
+CONFIG_NFS_V3=y
+CONFIG_NFS_V3_ACL=y
+CONFIG_NFS_V4=y
+CONFIG_NFS_SWAP=y
+CONFIG_NFS_V4_1=y
+CONFIG_PNFS_FILE_LAYOUT=m
+CONFIG_PNFS_BLOCK=m
+CONFIG_NFS_V4_1_IMPLEMENTATION_ID_DOMAIN="kernel.org"
+CONFIG_ROOT_NFS=y
+CONFIG_NFS_USE_LEGACY_DNS=y
+CONFIG_NFSD=y
+CONFIG_NFSD_V2_ACL=y
+CONFIG_NFSD_V3=y
+CONFIG_NFSD_V3_ACL=y
+CONFIG_NFSD_V4=y
+# CONFIG_NFSD_FAULT_INJECTION is not set
+CONFIG_LOCKD=y
+CONFIG_LOCKD_V4=y
+CONFIG_NFS_ACL_SUPPORT=y
+CONFIG_NFS_COMMON=y
+CONFIG_SUNRPC=y
+CONFIG_SUNRPC_GSS=y
+CONFIG_SUNRPC_BACKCHANNEL=y
+CONFIG_SUNRPC_SWAP=y
+# CONFIG_SUNRPC_DEBUG is not set
 # CONFIG_CEPH_FS is not set
 CONFIG_CIFS=y
 # CONFIG_CIFS_STATS is not set
@@ -3573,6 +3610,7 @@
 CONFIG_DEFAULT_SECURITY_SELINUX=y
 # CONFIG_DEFAULT_SECURITY_DAC is not set
 CONFIG_DEFAULT_SECURITY="selinux"
+CONFIG_XOR_BLOCKS=y
 CONFIG_CRYPTO=y
 
 #
@@ -3687,6 +3725,7 @@
 #
 # Library routines
 #
+CONFIG_RAID6_PQ=y
 CONFIG_BITREVERSE=y
 CONFIG_GENERIC_STRNCPY_FROM_USER=y
 CONFIG_GENERIC_STRNLEN_USER=y
@@ -3732,4 +3771,5 @@
 CONFIG_AVERAGE=y
 # CONFIG_CORDIC is not set
 # CONFIG_DDR is not set
+CONFIG_OID_REGISTRY=y
 # CONFIG_VIRTUALIZATION is not set
'


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



