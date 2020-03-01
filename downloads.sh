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
        cd $DIR && ( git reset --hard && git clean -xdfq && git checkout -f ${BRANCH} && git fetch && git pull origin ${BRANCH} ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
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
        tag)    ( git fetch -t && git checkout -f ${VAR} ) >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1 ;;
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
        # aarch64 change interpreter path
        [[ $ARCH == aarch64 ]] && change_interpreter_path "$SOURCE/$XTOOLS"
        ((c+=1))
    done
}

download() {

    [[ $MARCH == "x86_64" || $MARCH == aarch64 ]] && download_xtools

    message "" "download" "$BOOT_LOADER_DIR"
    # git_fetch <dir> <url> <branch>
    git_fetch $SOURCE/$BOOT_LOADER_DIR $BOOT_LOADER_SOURCE ${BOOT_LOADER_BRANCH}

    if [[ ! -z $BOOT_LOADER_TOOLS_SOURCE ]]; then
        message "" "download" "$BOOT_LOADER_TOOLS_DIR"
        # git_fetch <dir> <url> <branch>
        git_fetch $SOURCE/$BOOT_LOADER_TOOLS_DIR $BOOT_LOADER_TOOLS_SOURCE ${BOOT_LOADER_TOOLS_BRANCH}
    fi

    if [[ ! -z $ATF ]]; then
        message "" "download" "$ATF_DIR"
        # git_fetch <dir> <url> <branch>
        git_fetch $SOURCE/$ATF_DIR $ATF_SOURCE ${ATF_BRANCH}
    fi

    if [[ $SOCFAMILY == rk3* ]]; then
        message "" "download" "$RKBIN_DIR"
        # git_fetch <dir> <url> <branch>
        git_fetch $SOURCE/$RKBIN_DIR $RKBIN_SOURCE ${RKBIN_BRANCH}
    fi

    message "" "download" "$KERNEL_DIR"
    # git_fetch <dir> <url> <branch>
    git_fetch $SOURCE/$KERNEL_DIR $LINUX_SOURCE ${KERNEL_BRANCH}

    if [[ $SOCFAMILY == sun* ]]; then
        message "" "download" "$SUNXI_TOOLS"
        # git_fetch <dir> <url> <branch>
        git_fetch $SOURCE/$SUNXI_TOOLS_DIR $SUNXI_TOOLS_SOURCE ${SUNXI_TOOLS_BRANCH}
    fi
}
