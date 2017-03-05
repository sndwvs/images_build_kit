#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

#---------------------------------------------
# downloads sources and binares
#---------------------------------------------
download (){

    if ! $(echo "$MD5_XTOOLS  $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz" | md5sum --status -c - 2>/dev/null) ; then
        message "" "download" "$XTOOLS"
        [[ -f $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz ]] && rm $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        wget -c --no-check-certificate $URL_XTOOLS -O $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        message "" "extract" "$XTOOLS"
        tar xpf $CWD/$BUILD/$SOURCE/$XTOOLS.tar.?z* -C "$CWD/$BUILD/$SOURCE/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    message "" "download" "$BOOT_LOADER"
    if [ -d $CWD/$BUILD/$SOURCE/$BOOT_LOADER ]; then
        cd $CWD/$BUILD/$SOURCE/$BOOT_LOADER && ( git checkout -f ${BOOT_LOADER_BRANCH:-master} && git reset --hard && git pull origin ${BOOT_LOADER_BRANCH:-master} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    else
        git clone $URL_BOOT_LOADER_SOURCE/${BOOT_LOADER}.git $CWD/$BUILD/$SOURCE/$BOOT_LOADER >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    if [[ $SOCFAMILY == rk3288 ]]; then
        message "" "download" "$LINUX_UPGRADE_TOOL"
        wget -c --no-check-certificate $URL_LINUX_UPGRADE_TOOL/$LINUX_UPGRADE_TOOL.zip -O $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL.zip >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        unzip -o $CWD/$BUILD/$SOURCE/$LINUX_UPGRADE_TOOL.zip -d $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

        if [[ ! -z $XTOOLS_OLD ]]; then
            message "" "download" "$XTOOLS_OLD"
            if [[ -d $CWD/$BUILD/$SOURCE/$XTOOLS_OLD ]]; then
                cd $CWD/$BUILD/$SOURCE/$XTOOLS_OLD && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            else
                git clone $URL_XTOOLS_OLD $CWD/$BUILD/$SOURCE/$XTOOLS_OLD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
        fi

        message "" "download" "$RK2918_TOOLS"
        if [[ -d $CWD/$BUILD/$SOURCE/$RK2918_TOOLS ]]; then
            cd $CWD/$BUILD/$SOURCE/$RK2918_TOOLS && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_RK2918_TOOLS/$RK2918_TOOLS $CWD/$BUILD/$SOURCE/$RK2918_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi

        message "" "download" "$RKFLASH_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS ]; then
            cd $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_TOOLS/$RKFLASH_TOOLS $CWD/$BUILD/$SOURCE/$RKFLASH_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi

        message "" "download" "$MKBOOTIMG_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS ]; then
            cd $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS && git pull origin HEAD >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_TOOLS/$MKBOOTIMG_TOOLS $CWD/$BUILD/$SOURCE/$MKBOOTIMG_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi

        message "" "download" "$RKBIN"
        if [ -d $CWD/$BUILD/$SOURCE/$RKBIN ]; then
            cd $CWD/$BUILD/$SOURCE/$RKBIN && ( git checkout -f master && git reset --hard ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_RKBIN/${RKBIN}.git $CWD/$BUILD/$SOURCE/$RKBIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi

        message "" "download" "$KERNEL_DIR"
        if [[ $KERNEL_SOURCE == next ]]; then
            if [ -d $CWD/$BUILD/$SOURCE/$KERNEL_DIR ]; then
                cd $CWD/$BUILD/$SOURCE/$KERNEL_DIR && ( git checkout -f ${KERNEL_BRANCH:-master} && git reset --hard && git pull origin ${KERNEL_BRANCH:-master} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            else
                git clone -b $KERNEL_BRANCH --depth 1 $URL_LINUX_SOURCE/$LINUX_SOURCE $CWD/$BUILD/$SOURCE/$KERNEL_DIR >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
            message "" "extract" "$KERNEL_DIR"
            cd $CWD/$BUILD/$SOURCE/$KERNEL_DIR && git checkout $KERNEL_BRANCH >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

#            wget -c --no-check-certificate $URL_LINUX_SOURCE/$LINUX_SOURCE.tar.xz -O $CWD/$BUILD/$SOURCE/$LINUX_SOURCE.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

#            message "" "extract" "$LINUX_SOURCE"
#            tar xpf $CWD/$BUILD/$SOURCE/$LINUX_SOURCE.tar.xz -C "$CWD/$BUILD/$SOURCE/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            if [ -d $CWD/$BUILD/$SOURCE/$KERNEL_DIR ]; then
                cd $CWD/$BUILD/$SOURCE/$KERNEL_DIR && ( git checkout -f ${KERNEL_BRANCH:-master} && git reset --hard && git pull origin ${KERNEL_BRANCH:-master} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            else
                git clone -b $KERNEL_BRANCH --depth 1 $URL_LINUX_SOURCE/$LINUX_SOURCE $CWD/$BUILD/$SOURCE/$KERNEL_DIR >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
            message "" "extract" "$KERNEL_DIR"
            cd $CWD/$BUILD/$SOURCE/$KERNEL_DIR && git checkout $KERNEL_BRANCH >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    if [[ $SOCFAMILY == sun* ]]; then
        message "" "download" "$SUNXI_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS ];then
            cd $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS && ( git checkout -f ${SUNXI_TOOLS_BRANCH:-master} && git reset --hard && git pull origin ${SUNXI_TOOLS_BRANCH:-master} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_SUNXI_TOOLS/$SUNXI_TOOLS $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi

        message "" "download" "$KERNEL_DIR"
        if [[ $SOCFAMILY == sun8* ]] || [[ $KERNEL_SOURCE != next ]]; then
            if [ -d $CWD/$BUILD/$SOURCE/$KERNEL_DIR ]; then
                cd $CWD/$BUILD/$SOURCE/$KERNEL_DIR && ( git checkout -f ${KERNEL_BRANCH:-master} && git reset --hard && git pull origin ${KERNEL_BRANCH:-master} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            else
                git clone -b $KERNEL_BRANCH --depth 1 $URL_LINUX_SOURCE/$LINUX_SOURCE $CWD/$BUILD/$SOURCE/$KERNEL_DIR >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
            message "" "extract" "$KERNEL_DIR"
            cd $CWD/$BUILD/$SOURCE/$KERNEL_DIR && git checkout $KERNEL_BRANCH >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            wget -c --no-check-certificate $URL_LINUX_SOURCE/$LINUX_SOURCE.tar.xz -O $CWD/$BUILD/$SOURCE/$LINUX_SOURCE.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

            [[ ! -d "$CWD/$BUILD/$SOURCE/$KERNEL_DIR" ]] && "$CWD/$BUILD/$SOURCE/$KERNEL_DIR" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

            message "" "extract" "$KERNEL_DIR"
            tar --strip-components=1 -xpf $CWD/$BUILD/$SOURCE/$LINUX_SOURCE.tar.xz -C "$CWD/$BUILD/$SOURCE/$KERNEL_DIR" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi
}
