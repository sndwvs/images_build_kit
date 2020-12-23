#!/bin/bash



if [ -z $CWD ];then
    exit
fi


#---------------------------------------------
# display message
#---------------------------------------------
message() {
    # parametr 1 - type message
    #     "err"  - error
    #     "info" - info (default is empty)
    # parametr 2 - action message
    # parametr 3 - text message

    if [[ ! -z "$2" ]]; then ACTION="$2"; else unset ACTION; fi
    if [[ ! -z "$3" ]]; then MESSAGE="$3"; else unset MESSAGE; fi

    if [[ "$1" == "err" ]]; then
        printf '|\e[0;31m%s \x1B[0m| \e[0;32m%-12s\x1B[0m %s\n' "$1" "$ACTION" "$LOG"
    elif [[ "$1" == "info" || -z "$1" ]]; then
        printf '|\e[0;36minfo\x1B[0m| \e[0;32m%-12s\x1B[0m %s\n' "$ACTION" "$MESSAGE"
        [[ -f $LOG ]] && echo "|----------- delimiter ----------- \"$ACTION\" \"$MESSAGE\" -----------|" >> $LOG
    fi
    return 0
}

#---------------------------------------------
# get linux kernel version from Makefile
#---------------------------------------------
kernel_version() {
    local VER

    if [[ ! -f $SOURCE/$KERNEL_DIR/Makefile ]]; then
        echo "no get kernel version" >> $LOG
        (message "err" "details" && exit 1) || exit 1
    fi

    VER=$(cat $SOURCE/$KERNEL_DIR/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
    VER=$VER.$(cat $SOURCE/$KERNEL_DIR/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
    VER=$VER.$(cat $SOURCE/$KERNEL_DIR/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
    EXTRAVERSION=$(cat $SOURCE/$KERNEL_DIR/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
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

    # applied first
    message "" "added" "configuration file environment.conf"
    source "$CWD/config/environment/environment.conf" || exit 1

    for dir in "${dirs[@]}"; do
        for file in ${dir}/*.conf; do
            _file=$(basename ${file})
            if [[ $(echo "${dir}" | grep "environment") && "${_file}" != "environment.conf" ]]; then
                message "" "added" "configuration file $_file"
                source "$file" || exit 1
            fi
            if [[ -n ${BOARD_NAME} && ! ${_file%%${BOARD_NAME}*} ]]; then
                message "" "added" "configuration file $_file"
                source "$file" || exit 1
            fi
            if [[ -n ${SOCFAMILY} && ! ${_file%%${SOCFAMILY}*} ]]; then
                message "" "added" "configuration file $_file"
                source "$file" || exit 1
            fi
            #---- packages
#            for image_type in ${CREATE_IMAGE[@]}; do
#                if [[ $image_type = xfce ]]; then
#                    if [[ -n ${BOARD_NAME} && ! ${_file%%*-${BOARD_NAME}*} ]]; then
#                         message "" "added" "configuration file $_file"
#                         source "$file" || exit 1
#                    fi

#                    [[ $file = *extra* ]] && source "$file" && \
#                                            message "" "added" "configuration file $(basename $file)"

#                fi
#                if [[ ! ${_file%%*-${image_type}*} ]]; then
#                     message "" "added" "configuration file $_file"
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
                PATCH_SOURCE="$SOURCE/$KERNEL_DIR"
            ;;
        u-boot)
                dirs=(
                            "$CWD/patch/u-boot/$SOCFAMILY"
                            "$CWD/patch/u-boot/$SOCFAMILY/$KERNEL_SOURCE"
                            "$CWD/patch/u-boot/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$BOOT_LOADER_DIR"
            ;;
        u-boot-tools)
                dirs=(
                            "$CWD/patch/u-boot-tools/$SOCFAMILY"
                            "$CWD/patch/u-boot-tools/$SOCFAMILY/$KERNEL_SOURCE"
                            "$CWD/patch/u-boot-tools/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$BOOT_LOADER_TOOLS_DIR"
            ;;
        atf)
                dirs=(      "$CWD/patch/atf/$SOCFAMILY"
                            "$CWD/patch/atf/$SOCFAMILY/$BOARD_NAME"
                        )
                PATCH_SOURCE="$SOURCE/$ATF_DIR"
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

    pushd $PATCH_SOURCE >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1

    for file in "${names_s[@]}"; do
        for dir in "${dirs[@]}"; do
            if [[ -f "${dir}/${file}" ]]; then
                # detect and remove files which patch will create
                LANGUAGE=english patch --batch --dry-run -p1 -N < "${dir}/${file}" | grep create \
                        | awk '{print $NF}' | sed -n 's/,$//p' | xargs -I % sh -c 'rm %'

                if ! grep -qP '[Hh]unk.*(FAILED|ignored)' <(patch --batch -Np1 --dry-run < "${dir}/${file}"); then
                    patch --batch --silent -Np1 < "${dir}/${file}" >> $LOG 2>&1
                    message "" "patching" "succeeded: $file"
                else
                    message "" "patching" "not succeeded: $file"
#                    mv "${dir}/${file}" "${dir}/${file}.disabled"
                fi
            fi
        done
    done

    popd >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
}

#---------------------------------------------
# get gcc version
#---------------------------------------------
gcc_version() {
    local VER
    #VER=$( ${1}gcc --version | grep -oP "GCC.*(?=\))" )
    VER=$( ${1}gcc --version | grep 'GCC\|Toolchain' | rev | cut -d ')' -f1 | rev | sed 's:^\s::g' )
    eval "$2=\$VER"
}

#---------------------------------------------
# read packages
#---------------------------------------------
read_packages() {
    local TYPE="$1"
    local PKG
    [[ -f $CWD/config/packages/packages-${TYPE}.conf ]] && PKG=( $(grep -vP "^#|^$" $CWD/config/packages/packages-${TYPE}.conf) )
    eval "$2=\${PKG[*]}"
}


#---------------------------------------------
# change the name of the version u-boot kernel
#---------------------------------------------
change_name_version() {
    local SUFFIX="$1"
    [[ -f .config ]] && sed -i "s/CONFIG_LOCALVERSION=\"\"/CONFIG_LOCALVERSION=\"$SUFFIX\"/g" .config
    [[ -f .config ]] && sed -i "s/CONFIG_LOCALVERSION_AUTO=.*/# CONFIG_LOCALVERSION_AUTO is not set/g" .config

    # prevent adding + to kernel release
    touch .scmversion
}


#---------------------------------------------
# aarch64 change interpreter path
#---------------------------------------------
change_interpreter_path() {
    local EXECUTE_PATH="$@"
    for dir in ${EXECUTE_PATH[@]}; do
        if [[ -d "$SOURCE/$dir" ]]; then
            find "$SOURCE/$dir" | xargs file | grep -e "executable\(.*\)interpreter" \
            | grep ELF | cut -f1 -d ':' \
            | xargs -I '{}' patchelf --set-interpreter /lib64/ld-linux-aarch64.so.1 '{}' >> $LOG 2>&1 || (message "err" "details" && exit 1) || exit 1
        fi
    done
}


#---------------------------------------------
# clear boot tools
#---------------------------------------------
clear_boot_tools() {
    message "" "clear" "boot tools"
    [[ -d $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot ]] && rm -rf $BUILD/$OUTPUT/$TOOLS/$BOARD_NAME/boot
    return 0
}



