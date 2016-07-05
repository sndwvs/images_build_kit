#!/bin/bash

set -e


DISK="/dev/mmcblk1"
ROOT="${DISK}p1"


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


if [[ ! -b "$DISK" ]];then
    message "" "there is no section $ROOT for the system transfer"
    exit 1
fi

if [[ $(mount | grep "$ROOT") ]];then
    umount "$ROOT" >/dev/null 2>&1
fi

message "" "create" "partition"
echo -e "\ng\nn\n1\n81920\n\nw" | fdisk "$DISK" >/dev/null 2>&1

message "" "format" "the partition root $ROOT"
echo y | mkfs.ext4 "$ROOT" || exit 1

message "" "create" "the missing folder"
mkdir -p /nand/ || exit 1
mount $ROOT /nand/ || exit 1
mkdir -p /nand/{proc,sys} || exit 1

message "" "move" "to sd card on eMMC"
for d in $(ls / | grep -v "nand\|proc\|sys"); do
    message "" "copy" "data $d"
    cp -a "/$d" /nand/ || exit 1
done

umount "$ROOT" || exit 1
message "" "clean" "remove folder nand"
rmdir /nand || exit 1

message "" "finish" "data transferred to the eMMC"

message "" "warning" "do not forget to flash the following files"

message "" "info" "tools/upgrade_tool ul RK3288UbootLoader || exit 1"
message "" "info" "tools/rkflashtool P < parameters.txt || exit 1"
message "" "info" "tools/rkflashtool w kernel < kernel.img || exit 1"
message "" "info" "tools/rkflashtool w boot < boot.img || exit 1"
