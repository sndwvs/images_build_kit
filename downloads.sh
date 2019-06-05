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
        [[ 0 -ne $status ]] && ( git clone -b ${BRANCH} $URL $DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
    else
        cd $DIR && ( git reset --hard ${BRANCH} && git clean -xdfq && git checkout -f ${BRANCH} && git fetch && git pull origin ${BRANCH} ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
    fi
    pushd $DIR >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    set +e
    if [[ $TYPE == commit && ! $(git log --format=format:%H | grep $VAR) ]]; then
        i=1
        while [ ! $(git log --format=format:%H | grep $VAR) ]; do
            git fetch --depth=$((i+=600)) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
#            git log --format=format:%H | grep $VAR
        done
    fi
    set -e
    case $TYPE in
        tag)    ( git fetch && git checkout -f ${VAR} ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 ;;
        commit) ( git reset --hard ${VAR} && git fetch ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 ;;
    esac
    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

download_xtools() {
    local c=0
    for XTOOLS in ${XTOOLS[*]}; do
        if [[ $(echo $XTOOLS | grep $ARCH) || ! -z $ATF ]]; then
            [[ -f $SOURCE/$XTOOLS.tar.xz.asc ]] && rm $SOURCE/$XTOOLS.tar.xz.asc > /dev/null
            wget --no-check-certificate ${URL_XTOOLS[$c]}/$XTOOLS.tar.xz.asc -P $SOURCE/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            MD5_XTOOLS=$(awk '{print $1}' $SOURCE/$XTOOLS.tar.xz.asc)
            if ! $(echo "$MD5_XTOOLS  $SOURCE/$XTOOLS.tar.xz" | md5sum --status -c - 2>/dev/null) ; then
                message "" "download" "$XTOOLS"
                [[ -f $SOURCE/$XTOOLS.tar.xz ]] && ( rm $SOURCE/$XTOOLS.tar.xz >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 )
                wget --no-check-certificate ${URL_XTOOLS[$c]}/$XTOOLS.tar.xz -P $SOURCE/ >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
            if [[ ! -d $SOURCE/$XTOOLS ]]; then
                message "" "extract" "$XTOOLS"
                [[ -f $SOURCE/$XTOOLS.tar.xz ]] && tar xpf $SOURCE/$XTOOLS.tar.xz -C "$SOURCE/" >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
        fi
        ((c+=1))
    done
}

download() {

    [[ $NATIVE_ARCH != true ]] && download_xtools
#    [[ $NATIVE_ARCH != true || $ARCH == aarch64 ]] && download_xtools

    message "" "download" "$BOOT_LOADER_DIR"
    # git_fetch <dir> <url> <branch>
    git_fetch $SOURCE/$BOOT_LOADER_DIR $BOOT_LOADER_SOURCE ${BOOT_LOADER_BRANCH}

# after changes start
    if [[ ! -z $ATF ]]; then
        message "" "download" "$ATF_SOURCE"
        if [ -d $SOURCE/$ATF_SOURCE ]; then
            cd $SOURCE/$ATF_SOURCE && ( git fetch && git checkout -f ${ATF_BRANCH} && git clean -df && git pull origin ${ATF_BRANCH} ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone -b $ATF_BRANCH --depth 1 $URL_ATF/$ATF_SOURCE $SOURCE/$ATF_SOURCE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi

    if [[ $SOCFAMILY == rk3* ]]; then
        if [[ ! -z $XTOOLS_OLD ]]; then
            message "" "download" "$XTOOLS_OLD"
            if [[ -d $SOURCE/$XTOOLS_OLD ]]; then
                cd $SOURCE/$XTOOLS_OLD && ( git fetch && git pull origin HEAD ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            else
                git clone $URL_XTOOLS_OLD $SOURCE/$XTOOLS_OLD >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
            fi
        fi

        message "" "download" "$RKBIN"
        # git_fetch <dir> <url> <branch>
        git_fetch $SOURCE/$RKBIN $URL_RKBIN/$RKBIN ${RKBIN_BRANCH}
# after changes end
    fi

    message "" "download" "$KERNEL_DIR"
    # git_fetch <dir> <url> <branch>
    git_fetch $SOURCE/$KERNEL_DIR $LINUX_SOURCE ${KERNEL_BRANCH}

    if [[ $SOCFAMILY == sun* ]]; then
        message "" "download" "$SUNXI_TOOLS"
        if [ -d $SOURCE/$SUNXI_TOOLS ];then
            cd $SOURCE/$SUNXI_TOOLS && ( git fetch && git checkout -f ${SUNXI_TOOLS_BRANCH:-master} && git clean -df && git pull origin ${SUNXI_TOOLS_BRANCH:-master} ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        else
            git clone $URL_SUNXI_TOOLS/$SUNXI_TOOLS $SOURCE/$SUNXI_TOOLS >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    fi
}
