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
        echo -e "|\e[0;31m error \x1B[0m| $ACTION $MESSAGE"
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
    if [[ $KERNEL_SOURCE == "next" ]];then
        if [[ $BOARD_NAME == "firefly" ]];then
            VER=$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep VERSION | head -1 | awk '{print $(NF)}')
            VER=$VER.$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
            VER=$VER.$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
            EXTRAVERSION=$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
            if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
        else
            VER=$(wget --no-check-certificate -qO- https://www.kernel.org/finger_banner | grep "The latest stable" | awk '{print $NF}' | head -n1)
        fi
    else
        if [[ $BOARD_NAME == "cubietruck" ]];then
            VER=$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep VERSION | head -1 | awk '{print $(NF)}')
            VER=$VER.$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
            VER=$VER.$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
            EXTRAVERSION=$(wget --no-check-certificate -qO- $LINUX_SOURCE_VERSION | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
            if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
        fi
    fi

#    local VER
#    if [[ -z $NEXT ]];then
#        VER=$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
#	    VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
#	    VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
#	    EXTRAVERSION=$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
#	    if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
#    else
#	    VER=$(wget --no-check-certificate -qO-  https://www.kernel.org/finger_banner | grep "The latest mainline" | awk '{print $NF}')
#    fi

#    message "" "get" "kernel version $VER"
    eval "$1=\$VER"
}

#---------------------------------------------
# get config
#---------------------------------------------
get_config() {
    local dirs=("$CWD/config/environment" "$CWD/config/boards/$BOARD_NAME" "$CWD/config/packages")
    for dir in "${dirs[@]}"; do
        for file in ${dir}/*.conf; do
            if $(echo "${dir}" | grep -q "environment"); then
                message "" "add" "configuration file $(basename $file)"
                source "$file" || exit 1
            fi
            if $(echo "$file" | grep -q "$BOARD_NAME"); then
                message "" "add" "configuration file $(basename $file)"
                source "$file" || exit 1
            fi
            for image_type in ${CREATE_IMAGE[@]}; do
                if $(echo "$file" | grep -q "$image_type"); then
                     message "" "add" "configuration file $(basename $file)"
                     source "$file" || exit 1
                fi
            done
        done
    done
}

#---------------------------------------------
# kernel patching process
#---------------------------------------------
patching_kernel_source() {
    local dir="$CWD/patch/kernel/$SOCFAMILY-$KERNEL_SOURCE"
    cd $CWD/$BUILD/$SOURCE/$LINUX_SOURCE >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
    for file in "$dir/*.patch"; do
             names+=($(basename -a $file)) || exit 1
    done

    for file in "${names[@]}"; do
        if [[ $(echo "$file" | grep -v "disable") ]]; then
            if [ "$(patch --dry-run -t -p1 < $dir/${file} | grep Reversed)" == "" ]; then
                message "" "patching" "$file"
                patch --batch -f -p1 < $dir/${file} >> $CWD/$BUILD/$SOURCE/$LOG 2>&1 || (message "err" "details" "$BUILD/$SOURCE/$LOG" && exit 1) || exit 1
            fi
        fi
    done
}


