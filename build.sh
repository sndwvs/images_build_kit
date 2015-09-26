#!/bin/bash



#---------------------------------------------
# environment
#---------------------------------------------
CWD=$(pwd)



# commandline arguments processing
while [ 1 ]
do
    case "$1" in
	-d | --download )
	    shift
	    DOWNLOAD_SOURCE_BINARIES="true"
	    ;;
	-b | --board )
	    if [ $(echo "$2" | egrep "cubietruck|firefly") ]; then
		BOARD_NAME="$2"
	        shift 2
	    else
		exit -1
	    fi
	    ;;
	-p | --patch )
	    shift
	    APPLY_PATCH="true"
	    ;;
	--clean )
	    shift
	    CLEAN="true"
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
	--next )
	    shift
	    NEXT="next"
	    ;;
	-h | --help )
	    echo -e "Usage: run as root: $0 <options>"
	    echo -e "Options:"
	    echo -e "\t--clean"
	    echo -e "\t\tclean sources, remove binaries and image"

	    echo -e "\t-d | --download"
	    echo -e "\t\tdownload source and use pre-built binaries"

	    echo -e "\t-b | --board"
	    echo -e "\t\tbuild for board cubietruck | firefly"

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

	    echo -e "\t--next"
	    echo -e "\t\tmainline kernel"
    
	    exit 0
	    ;;
	"" )
#	    shift
	    break
	    ;;

    esac
done




#---------------------------------------------
# configuration
#---------------------------------------------
source $CWD/configuration.sh
source $CWD/compilation.sh
source $CWD/build_slackware_rootfs.sh




#---------------------------------------------
# main script
#---------------------------------------------

if [ "$CLEAN" == "true" ]; then
    clean_sources
fi

if [ ! -e "$BOARD_NAME" ]; then
    prepare_dest
fi

if [ "$DOWNLOAD_SOURCE_BINARIES" == "true" ]; then
    download
fi

if [ "$COMPILE_BINARIES" == "true" ]; then
    if [ "$BOARD_NAME" == "firefly" ]; then
        compile_rk2918
        compile_rkflashtool
        compile_mkbooting
        add_linux_upgrade_tool
        build_parameters
        build_resource
        build_boot
    fi

    if [ "$BOARD_NAME" == "cubietruck" ]; then
        patching_kernel_sources
        compile_sunxi_tools
    fi
    compile_boot_loader
    compile_kernel
    build_pkg
fi

if [ "$TOOLS_PACK" == "true" ]; then
    build_flash_script
    create_tools_pack
fi

if [ "$CREATE_IMAGE" == "true" ]; then
    clean_rootfs
    download_rootfs
    prepare
    setting_fstab
    setting_motd
    setting_rc_local
    setting_wifi
    setting_dhcpcd
    setting_firstboot
    if [ "$XFCE" == "true" ]; then
	cp -fr $CWD/$BUILD/$SOURCE/${ROOTFS}-$BOARD_NAME-build-${VERSION}/ $CWD/$BUILD/$SOURCE/${ROOTFS_XFCE}-$BOARD_NAME-build-${VERSION} || exit 1
	download_pkg
	install_pkg
	setting_default_theme_xfce
	setting_default_start_x
	if [ "$BOARD_NAME" == "firefly" ]; then
	    download_video_driver
	    build_video_driver_pkg
	    install_video_driver_pkg
	fi
	create_img xfce
    fi
    create_img
fi



