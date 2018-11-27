#!/bin/bash



if [ -z $CWD ];then
    exit
fi


#---------------------------------------------
# display message
#---------------------------------------------
message() {
    # parametr 1 - type message
    #     0 - error
    #     1 - info (default is empty)
    # parametr 2 - action message
    # parametr 3 - text message

    if [[ ! -z $2 ]]; then ACTION="\e[0;32m $2 \x1B[0m"; else unset ACTION; fi
    if [[ ! -z $3 ]]; then MESSAGE="\e[0;37m $3 \x1B[0m"; else unset MESSAGE; fi

    if [[ $1 == "err" ]]; then
        echo -e "|\e[0;31m error \x1B[0m| $ACTION $BUILD/$SOURCE/$LOG"
    elif [[ $1 == "info" ]]; then
        echo -e "|\e[0;36m info \x1B[0m| $ACTION $MESSAGE"
    else
        echo -e "|\e[0;36m info \x1B[0m| $ACTION $MESSAGE"
    fi
}

#---------------------------------------------
# get linux kernel version from Makefile
#---------------------------------------------
kernel_version() {
    local VER

    if [[ ! -f $CWD/$BUILD/$SOURCE/$KERNEL_DIR/Makefile ]]; then
        echo "no get kernel version" >> $CWD/$BUILD/$SOURCE/$LOG
        (message "err" "details" && exit 1) || exit 1
    fi

    VER=$(cat $CWD/$BUILD/$SOURCE/$KERNEL_DIR/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
    VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$KERNEL_DIR/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
    VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$KERNEL_DIR/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
    EXTRAVERSION=$(cat $CWD/$BUILD/$SOURCE/$KERNEL_DIR/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
    if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
#    message "" "get" "kernel version $VER"
    eval "$1=\$VER"
}

#---------------------------------------------
# get config
#---------------------------------------------
get_config() {
    local dirs=(    "$CWD/config/environment"
                    "$CWD/config/boards/$BOARD_NAME"
                    "$CWD/config/sources/$SOCFAMILY"
#                    "$CWD/config/packages"
                )
    for dir in "${dirs[@]}"; do
        for file in ${dir}/*.conf; do
            _file=$(basename ${file})
            if $(echo "${dir}" | grep -q "environment"); then
                message "" "add" "configuration file $_file"
                source "$file" || exit 1
            fi
            if [[ -n ${BOARD_NAME} && ! ${_file%%${BOARD_NAME}*} ]]; then
                message "" "add" "configuration file $_file"
                source "$file" || exit 1
            fi
            if [[ -n ${SOCFAMILY} && ! ${_file%%${SOCFAMILY}*} ]]; then
                message "" "add" "configuration file $_file"
                source "$file" || exit 1
            fi
            #---- packages
#            for image_type in ${CREATE_IMAGE[@]}; do
#                if [[ $image_type = xfce ]]; then
#                    if [[ -n ${BOARD_NAME} && ! ${_file%%*-${BOARD_NAME}*} ]]; then
#                         message "" "add" "configuration file $_file"
#                         source "$file" || exit 1
#                    fi

#                    [[ $file = *extra* ]] && source "$file" && \
#                                            message "" "add" "configuration file $(basename $file)"

#                fi
#                if [[ ! ${_file%%*-${image_type}*} ]]; then
#                     message "" "add" "configuration file $_file"
#                     source "$file" || exit 1
#                fi
#            done
            #---- packages
        done
    done
}

#---------------------------------------------
# patching process
#---------------------------------------------
patching_source() {

    local dirs
    local PATCH_SOURCE
    local names=()

    case "$1" in
        kernel)
                dirs=(      "$CWD/patch/kernel/$SOCFAMILY-$KERNEL_SOURCE"
                            "$CWD/patch/kernel/$SOCFAMILY-$KERNEL_SOURCE/$BOARD_NAME"
                        )
                PATCH_SOURCE="$CWD/$BUILD/$SOURCE/$KERNEL_DIR"
            ;;
        u-boot)
                dirs=(
                            "$CWD/patch/u-boot/$SOCFAMILY"
                            "$CWD/patch/u-boot/$SOCFAMILY/$KERNEL_SOURCE"
                            "$CWD/patch/u-boot/$SOCFAMILY/$BOARD_NAME"
                            "$CWD/patch/u-boot/$SOCFAMILY/$BOARD_NAME/$KERNEL_SOURCE"
                        )
                PATCH_SOURCE="$CWD/$BUILD/$SOURCE/$BOOT_LOADER_DIR"
            ;;
    esac


    # required for "for" command
    shopt -s nullglob dotglob
    for dir in "${dirs[@]}"; do
        for file in ${dir%%:*}/*.patch; do
            names+=($(basename $file)) || exit 1
        done
    done

    # remove duplicates
    local names_s=($(echo "${names[@]}" | sed 's/\s/\n/g' | LC_ALL=C sort -u | sed 's/\n/\s/g'))

    [[ -z $names_s ]] && return 0

    pushd $PATCH_SOURCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    for file in "${names_s[@]}"; do
        for dir in "${dirs[@]}"; do
            if [[ -f "${dir}/${file}" ]]; then
                # detect and remove files which patch will create
                LANGUAGE=english patch --batch --dry-run -p1 -N < "${dir}/${file}" | grep create \
                        | awk '{print $NF}' | sed -n 's/,$//p' | xargs -I % sh -c 'rm %'

                patch --batch --silent -p1 -N < "${dir}/${file}" >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
                if [[ $? -eq 0 ]]; then
                    message "" "patching" "succeeded $file"
                fi
            fi
        done
    done
}

#---------------------------------------------
# get gcc version
#---------------------------------------------
gcc_version() {
    local VER
    #VER=$( ${1}gcc --version | grep -oP "GCC.*(?=\))" )
    VER=$( ${1}gcc --version | grep GCC | cut -d ' ' -f1,3 )
    eval "$2=\$VER"
}

#---------------------------------------------
# read packages
#---------------------------------------------
read_packages() {
    local TYPE="$1"
    local PKG
    PKG=( $(cat $CWD/config/packages/packages-${TYPE}.conf | grep -v "^#") )
    eval "$2=\${PKG[*]}"
}



