#!/bin/bash



#---------------------------------------------
# environment
#---------------------------------------------
CWD=$(pwd)



#---------------------------------------------
# configuration
#---------------------------------------------
source $CWD/configuration.sh
source $CWD/compilation.sh
source $CWD/build_slackware_rootfs.sh



# commandline arguments processing
while [ "x$1" != "x" ]
do
    case "$1" in
	-d | --download )
	    shift
	    DOWNLOAD_SOURCE_BINARIES="true"
	    ;;
	-p | --patch )
	    shift
	    APPLY_PATCH="true"
	    ;;
	--clean )
	    shift
	    clean_sources
	    exit -1
	    ;;
	-c | --compile )
	    shift
	    COMPILE_BINARIES="true"
	    ;;
	-i | --create-image )
	    shift
	    CREATE_IMAGE="true"
	    ;;
	-t | --tools )
	    shift
	    TOOLS_PACK="true"
	    ;;
	--xfce )
	    shift
	    XFCE="true"
	    ;;

	-h | --help )
	    echo -e "Usage: run as root: $0 <options>"
	    echo -e "Options:"
	    echo -e "\t--clean"
	    echo -e "\t\tclean sources, remove binaries and image"

	    echo -e "\t-d | --download"
	    echo -e "\t\tdownload source and use pre-built binaries"

	    echo -e "\t-p | --patch"
	    echo -e "\t\tpatch the kernel configuration"

	    echo -e "\t-c | --compile"
	    echo -e "\t\tbuild binaries locally"

	    echo -e "\t-i | --create-image (default)"
	    echo -e "\t\tgenerate image"

	    echo -e "\t-t | --tools"
	    echo -e "\t\tcreate and pack tools"

	    echo -e "\t--xfce"
	    echo -e "\t\tcreate image with xfce"

	    exit 0
	    ;;
    esac
done


#---------------------------------------------
# main script
#---------------------------------------------
prepare_dest

if [ "$DOWNLOAD_SOURCE_BINARIES" = "true" ]; then
    download
fi

if [ "$COMPILE_BINARIES" = "true" ]; then
    compile_rk2918
    compile_rkflashtool
    compile_mkbooting
    compile_boot_loader
    compile_kernel
    build_pkg
    add_linux_upgrade_tool
    build_parameters
    build_resource
    build_boot
fi

if [ "$TOOLS_PACK" = "true" ]; then
    build_flash_script
    create_tools_pack
fi

if [ "$CREATE_IMAGE" = "true" ]; then
    clean_rootfs
    download_rootfs
    prepare
    setting_fstab
    setting_motd
    setting_wifi
    setting_dhcpcd
    setting_firstboot
    if [ "$XFCE" = "true" ]; then
	cp -fr $CWD/$BUILD/$SOURCE/${ROOTFS}-build-${VERSION}/ $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-build-${VERSION} || exit 1
	download_pkg
	install_pkg
	setting_default_theme_xfce
	setting_default_start_x
	download_video_driver
	build_video_driver_pkg
	install_video_driver_pkg
	create_img xfce
    fi
    create_img
fi



