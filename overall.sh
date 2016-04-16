#!/bin/bash



if [ -z $CWD ];then
    exit
fi


#---------------------------------------------
# display message
#---------------------------------------------
message (){
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
kernel_version (){
    if [[ -z $NEXT && ! -d $CWD/$BUILD/$SOURCE/$LINUX_SOURCE ]];then
        message "err" "get" "kernel"
        return 1
    fi

    local VER
    if [[ -z $NEXT ]];then
        VER=$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
	    VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
	    VER=$VER.$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
	    EXTRAVERSION=$(cat $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/Makefile | grep EXTRAVERSION | head -1 | awk '{print $(NF)}')
	    if [ "$EXTRAVERSION" != "=" ]; then VER=$VER$EXTRAVERSION; fi
    else
	    VER=$(wget --no-check-certificate -qO-  https://www.kernel.org/finger_banner | grep "The latest mainline" | awk '{print $NF}')
    fi

#    message "" "get" "kernel version $VER"
    eval "$1=\$VER"
}
