#!/bin/bash



if [ -z $CWD ]; then
    exit
fi

#---------------------------------------------
# downloads sources and binares
#---------------------------------------------


# $1 upload directory
# $2 repository url
# $3 branch
#            <branch>:<tag|commit>:value
git_fetch() {
    local DIR=$1
    local URL=$2
    local BRANCH=$(echo $3 | cut -f1 -d ":")
    local TYPE=$(echo $3 | cut -f2 -d ":")
    local VAR=$(echo $3 | cut -f3 -d ":")

    [[ -z $DIR || -z $URL ]] && ( message "err" "details" && exit 1 )

    if [[ ! -d $DIR ]]; then
        git clone -b ${BRANCH} --depth 1 $URL $DIR 2>/dev/null || status=$?
        [[ 0 -ne $status ]] && ( git clone -b ${BRANCH} $URL $DIR >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    else
        cd $DIR && ( git checkout -f ${BRANCH} && git clean -df && git pull origin ${BRANCH} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi

    pushd $DIR >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    set +e
    if [[ $TYPE == commit && ! $(git log --format=format:%H | grep $VAR) ]]; then
        i=1
        while [ ! $(git log --format=format:%H | grep $VAR) ]; do
            git fetch --depth=$((i+=10)) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#            git log --format=format:%H | grep $VAR
        done
    fi
    set -e
    case $TYPE in
        tag)    git checkout -f ${VAR} >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 ;;
        commit) git reset --hard ${VAR} >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 ;;
    esac
    popd >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

download_xtools() {
    local c=0
    for XTOOLS in ${XTOOLS[*]}; do
        if [[ $(echo $XTOOLS | grep $ARCH) ]]; then
            [[ -f $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz.asc ]] && rm $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz.asc > /dev/null
            wget --no-check-certificate ${URL_XTOOLS[$c]}/$XTOOLS.tar.xz.asc -P $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            MD5_XTOOLS=$(awk '{print $1}' $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz.asc)
            if ! $(echo "$MD5_XTOOLS  $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz" | md5sum --status -c - 2>/dev/null) ; then
                message "" "download" "$XTOOLS"
                [[ -f $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz ]] && ( rm $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
                wget --no-check-certificate ${URL_XTOOLS[$c]}/$XTOOLS.tar.xz -P $CWD/$BUILD/$SOURCE/ >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
            if [[ ! -d $CWD/$BUILD/$SOURCE/$XTOOLS ]]; then
                message "" "extract" "$XTOOLS"
                [[ -f $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz ]] && tar xpf $CWD/$BUILD/$SOURCE/$XTOOLS.tar.xz -C "$CWD/$BUILD/$SOURCE/" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
        fi
        ((c+=1))
    done
}

download() {

    download_xtools

    message "" "download" "$BOOT_LOADER_DIR"
    # git_fetch <dir> <url> <branch>
    git_fetch $CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR $BOOT_LOADER_SOURCE ${BOOT_LOADER_BRANCH}

# after changes start
    if [[ ! -z $ATF ]]; then
        message "" "download" "$ATF_SOURCE"
        if [ -d $CWD/$BUILD/$SOURCE/$ATF_SOURCE ]; then
            cd $CWD/$BUILD/$SOURCE/$ATF_SOURCE && ( git checkout -f ${ATF_BRANCH} && git clean -df && git pull origin ${ATF_BRANCH} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone -b $ATF_BRANCH --depth 1 $URL_ATF/$ATF_SOURCE $CWD/$BUILD/$SOURCE/$ATF_SOURCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    if [[ $SOCFAMILY == rk3* ]]; then
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
            cd $CWD/$BUILD/$SOURCE/$RKBIN && ( git checkout -f ${RKBIN_BRANCH:-master} && git clean -df && git pull origin ${RKBIN_BRANCH:-master} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_RKBIN/${RKBIN}.git $CWD/$BUILD/$SOURCE/$RKBIN >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
# after changes end
    fi

    message "" "download" "$KERNEL_DIR"
    # git_fetch <dir> <url> <branch>
    git_fetch $CWD/$BUILD/$SOURCE/$KERNEL_DIR $LINUX_SOURCE ${KERNEL_BRANCH}

    if [[ $SOCFAMILY == sun* ]]; then
        message "" "download" "$SUNXI_TOOLS"
        if [ -d $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS ];then
            cd $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS && ( git checkout -f ${SUNXI_TOOLS_BRANCH:-master} && git clean -df && git pull origin ${SUNXI_TOOLS_BRANCH:-master} ) >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_SUNXI_TOOLS/$SUNXI_TOOLS $CWD/$BUILD/$SOURCE/$SUNXI_TOOLS >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi
}
