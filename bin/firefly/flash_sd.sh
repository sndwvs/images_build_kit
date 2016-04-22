#!/bin/bash

set -e

SDCARD=""
RKCRC="tools/rkcrc"
SDBOOT="sdboot_rk3288.img"
PARAMETER_FILE="parameters.txt"
PARAMETER_IMG="parameters.img"
BOOT_IMG="boot.img"
KERNEL_IMG="kernel.img"
LINUXROOT_IMG=""


msg () {
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    # Generate the dialog box
    result=$(dialog --title "message" \
      --infobox "$1" 10 50 2>&1 1>&3)
    sleep 2
    # Close file descriptor 3
    exec 3>&-
}

get_disks () {
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1

    header=(dialog --title "select sdcard or usb disk" \
                   --radiolist "select disk" 21 76 10)
    for disk in $(ls /sys/block/ | grep '\(s\|h\)d[b-z]');do
        item+=("$disk" "select disk for flash /dev/$disk" "off")
    done

    while true; do
        if [ -z "$item" ]; then
            msg "the system no removable drives"
            exit 1
        fi

        result=$("${header[@]}" "${item[@]}" 2>&1 1>&3)

        if [ ! -z "$result" ]; then
            break
        fi
    done

    exit_status=$?
    # Close file descriptor 3
    exec 3>&-

    case $exit_status in
      0)
        SDCARD="/dev/$result";;
      *)
        exit 1
        ;;
    esac

    unset item
    unset result

}

get_image () {
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1

    header=(dialog --title "select image for flash" \
                   --radiolist "select image" 21 76 10)
    for image in $(ls | grep '^slack\(.*\)\.img');do
        type=$(echo $image | cut -f3 -d - | cut -f1 -d _)
        item+=("${type}" "$image" "off")
    done

    while true; do
        if [ -z "$item" ]; then
            msg "image of the installation of the system is not found"
            exit 1
        fi

        result=$("${header[@]}" "${item[@]}" 2>&1 1>&3)

        if [ ! -z "$result" ]; then
            break
        fi
    done

    exit_status=$?
    # Close file descriptor 3
    exec 3>&-

    case $exit_status in
      0)
        for image in $(ls | grep '^slack\(.*\)\.img');do
            if [[ "$image" =~ "${result}" ]]; then
                LINUXROOT_IMG="$image"
            fi
        done
        ;;
      *)
        exit 1;;
    esac
}

get_disks
get_image
#echo $SDCARD
#echo $LINUXROOT_IMG
#exit
reset

calculate_partitions_for_sdcard () {
    echo "Calculating partition size for ${SDCARD}"
    for PARTITION in $(cat ${PARAMETER_FILE} | grep '^CMDLINE' | sed 's/ //g' | sed 's/.*:\(0x.*[^)])\).*/\1/' | sed 's/,/ /g'); do
            PARTITION_NAME=`echo ${PARTITION} | sed 's/\(.*\)(\(.*\))/\2/'`
            START_PARTITION=`echo ${PARTITION} | sed 's/.*@\(.*\)(.*)/\1/'`
            LENGTH_PARTITION=`echo ${PARTITION} | sed 's/\(.*\)@.*/\1/'`
        case ${PARTITION_NAME} in
            "boot")
                    BOOT_PARTITION=true
                            BOOT_START_PARTITION=${START_PARTITION}
                            BOOT_LENGTH_PARTITION=${LENGTH_PARTITION}
                    ;;
            "kernel")
                    KERNEL_PARTITION=true
                            KERNEL_START_PARTITION=${START_PARTITION}
                            KERNEL_LENGTH_PARTITION=${LENGTH_PARTITION}
                    ;;
            "linuxroot")
                    LINUXROOT_PARTITION=true
                            LINUXROOT_START_PARTITION=${START_PARTITION}
                            LINUXROOT_LENGTH_PARTITION=${LENGTH_PARTITION}
                    ;;
            *)
                    ;;
        esac
    done

    for PARTITION in BOOT KERNEL LINUXROOT
    do
            eval PARTITION_EXISTS=${PARTITION}_PARTITION
            if ! ${!PARTITION_EXISTS}; then
                    ERROR "Linux's parameter file missing '`echo ${PARTITION} | tr '[:upper:]' '[:lower:]'`' partition definition"
            fi
    done

    PARTITION_NUMBER=1
    PARTITION="linuxroot"
    START_OF_PARTITION=$(((0x2000+0x2000+BOOT_LENGTH_PARTITION+KERNEL_LENGTH_PARTITION)*512/1024/1024))
    echo "Creating $(echo ${PARTITION} | tr '[:upper:]' '[:lower:]') partition as ${SDCARD}${PARTITION_NUMBER} on ${SDCARD}"
   ## echo "sgdisk ${PARTITION_NUMBER}:${START_OF_PARTITION}M: -t ${PARTITION_NUMBER}:8300 ${SDCARD}" # > /dev/null 2>&1
   ## sgdisk ${PARTITION_NUMBER}:${START_OF_PARTITION}M: -t ${PARTITION_NUMBER}:8300 ${SDCARD} # > /dev/null 2>&1
    echo "Making ext4 file system for $(echo ${PARTITION} | tr '[:upper:]' '[:lower:]') partition on ${SDCARD}${PARTITION_NUMBER}"
    #echo -e "o\np\nn\np\n${PARTITION_NUMBER}\n\n\nw" | fdisk ${SDCARD}
     #echo -e "\nd\nn\n${PARTITION_NUMBER}\n${START_OF_PARTITION}M\n\n8300\n\nw\ny" | gdisk ${SDCARD}
    echo -e "\n2\no\ny\np\nn\n\n${START_OF_PARTITION}M\n\n8300\n\nw\ny" | gdisk ${SDCARD} > /dev/null 2>&1
    partprobe ${SDCARD}
    #mkfs.ext4 -F ${SDCARD}${PARTITION_NUMBER} > /dev/null 2>&1
}


echo "Zero the beginning of the USB drive ${SDCARD}"
dd if=/dev/zero of=${SDCARD} bs=1M count=8 > /dev/null 2>&1

#sgdisk -Z ${SDCARD} > /dev/null 2>&1
echo -e "\nx\nz\ny\ny" | gdisk ${SDCARD} > /dev/null 2>&1
echo "Flashing sdboot to ${SDCARD}"
dd if=${SDBOOT} of=${SDCARD} conv=sync,fsync > /dev/null 2>&1
#sgdisk -og ${SDCARD} > /dev/null 2>&1
echo -e "\nx\no\ng\nr\nw\ny" | gdisk ${SDCARD} > /dev/null 2>&1

calculate_partitions_for_sdcard

echo $((0x2000))
echo "kernel" $((0x2000+KERNEL_START_PARTITION))
echo "boot" $((0x2000+BOOT_START_PARTITION))
echo "rootlinux" $((0x2000+LINUXROOT_START_PARTITION))

${RKCRC} -p ${PARAMETER_FILE} ${PARAMETER_IMG} || exit 1

echo "Flashing ${PARAMETER_IMG} to ${SDCARD}"
dd if=${PARAMETER_IMG} of=${SDCARD} conv=sync,fsync seek=$((0x2000)) > /dev/null 2>&1

echo "Flashing ${BOOT_IMG} to ${SDCARD}"
dd if=${BOOT_IMG} of=${SDCARD} conv=sync,fsync seek=$((0x2000+BOOT_START_PARTITION)) > /dev/null 2>&1

echo "Flashing ${KERNEL_IMG} to ${SDCARD}"
dd if=${KERNEL_IMG} of=${SDCARD} conv=sync,fsync seek=$((0x2000+KERNEL_START_PARTITION)) > /dev/null 2>&1

echo "Flashing linuxroot ${LINUXROOT_IMG} to ${SDCARD}${PARTITION_NUMBER}"
dd if=${LINUXROOT_IMG} of=${SDCARD}${PARTITION_NUMBER} conv=sync,fsync > /dev/null 2>&1
e2fsck -fp ${SDCARD}${PARTITION_NUMBER} > /dev/null 2>&1
resize2fs ${SDCARD}${PARTITION_NUMBER} > /dev/null 2>&1
