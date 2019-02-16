#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#---------------------------------------------
# configuration
#---------------------------------------------
ROOT_DISK=$(lsblk -in |  grep "/$" | cut -d '-' -f2 | cut -d ' ' -f1 | sed 's/^\([a-z]*\)\([0-9]*\)\(\w*\)/\1\2/')
DIRS=("/bin" "/boot" "/dev" "/etc" "/home" "/lib" "/media" "/mnt" "/opt" "/root" "/run" "/sbin" "/srv" "/swap" "/tmp" "/usr" "/var")
OUTPUT="/prepare"
OFFSET=$(fdisk -l /dev/$ROOT_DISK | tac | head -n 1 | awk '{print $2}')
PART=1


case $(cat /proc/device-tree/compatible) in
    *firefly*rk33*)
            OFFSET_LOADER="64:16384:24576"
            LOADER="idbloader.img:uboot.img:trust.img"
            FIX_BOOT_DISK=1
    ;;
    *rock*64*|rock*pi*4)
            OFFSET_LOADER="64"
            LOADER="rksd_loader.img"
            FIX_BOOT_DISK=1
    ;;
    *rk32*)
            OFFSET_LOADER="64::"
            LOADER="idbloader.img::"
            FIX_BOOT_DISK=1
    ;;
    *cubietruck*|*orange*pi*plus*2e*)
            OFFSET_LOADER="8::"
            LOADER="u-boot-sunxi-with-spl.bin::"
            BS=1024
    ;;
    *)
            exit
    ;;

esac


#---------------------------------------------
# selected message
#---------------------------------------------
msg() {
    local title=$1
    local message=$2

    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    # Generate the dialog box
    result=$(dialog --clear --title "$title" \
                    --yesno "$message" 10 60 2>&1 1>&3)
    # Close file descriptor 3
    exec 3>&-

#    exit_status=$?

#    if [ $? -eq 0 ]; then
#      echo "yes "$exit_status
#    fi
}

#---------------------------------------------
# info message
#---------------------------------------------
msginfo() {
    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    # Generate the dialog box
    result=$(dialog --title "message" \
      --infobox "$1" 10 50 2>&1 1>&3)
    sleep 2
    # Close file descriptor 3
    exec 3>&-

    sleep 2
}

#---------------------------------------------
# display menu
#---------------------------------------------
menu() {
    declare -a _title="$1"
    declare -a _description="$2"
    declare -a _options=("${!3}")

    # Duplicate file descriptor 1 on descriptor 3
    exec 3>&1
    # Generate the dialog box
    cmd=(dialog --clear --title "$_title" --menu "$_description" 12 60 3)
    # Close file descriptor 3
    result=$("${cmd[@]}" "${_options[@]}" 2>&1 1>&3)

    exec 3>&-

    exit_status=$?

    if [ $? -eq 0 ]; then
      eval "$4=\$result"
    fi
}

#---------------------------------------------
# selected disk
#---------------------------------------------
get_disks() {
    disks=($(lsblk | awk '{ if ($6 == "disk" && $1 !~ /boot|rpmb/)  print $1}'))

    local options

    for disk in "${disks[@]}"; do
        if [[ ! $disk* =~ $ROOT_DISK ]]; then
            options+=("$disk" "select disk for install")
        fi
    done

    menu "system configuration" "\nselect disk" options[@] OUT

    msg "WARNING" "Attention! Be careful subsequent operations can destroy your data on disk\n\n/dev/$OUT"

    if [ $? -eq 0 ]; then
      eval "$1=\$OUT"
    fi
}

#---------------------------------------------
# prepare disk
#---------------------------------------------
prepare_disk() {
    local DISK=$1

    if [[ ! -d $OUTPUT ]]; then
        mkdir -p $OUTPUT
    fi

    SPL_LOADER=$(echo $LOADER | cut -d ':' -f1)
    UBOOT_LOADER=$(echo $LOADER | cut -d ':' -f2)
    TRUST_LOADER=$(echo $LOADER | cut -d ':' -f3)

    SPL_OFFSET_LOADER=$(echo $OFFSET_LOADER | cut -d ':' -f1)
    UBOOT_OFFSET_LOADER=$(echo $OFFSET_LOADER | cut -d ':' -f2)
    TRUST_OFFSET_LOADER=$(echo $OFFSET_LOADER | cut -d ':' -f3)

    # clear partition
    dd if=/dev/zero of=/dev/$DISK bs=1k count=446 status=noxfer >/dev/null 2>&1

    # save u-boot
    if [[ ! -z $SPL_LOADER && ! -z $BS ]]; then
        dd if=/boot/$SPL_LOADER of=/dev/$DISK bs=$BS seek=$SPL_OFFSET_LOADER status=noxfer >/dev/null 2>&1
    fi

    if [[ ! -z $SPL_LOADER && -z $BS ]]; then
        dd if=/boot/$SPL_LOADER of=/dev/$DISK seek=$SPL_OFFSET_LOADER status=noxfer >/dev/null 2>&1
    fi

    if [[ ! -z $UBOOT_LOADER ]]; then
        dd if=/boot/$UBOOT_LOADER of=/dev/$DISK seek=$UBOOT_OFFSET_LOADER status=noxfer >/dev/null 2>&1
    fi

    if [[ ! -z $TRUST_LOADER ]]; then
        dd if=/boot/$TRUST_LOADER of=/dev/$DISK seek=$TRUST_OFFSET_LOADER status=noxfer >/dev/null 2>&1
    fi

    echo -e "\nn\np\n${PART}\n${OFFSET}\n\nw" | fdisk "/dev/$DISK" >/dev/null 2>&1

    if [[ $DISK =~ mmc* ]] ;then
        DISK=${DISK}p${PART}
    else
        DISK=${DISK}${PART}
    fi

    echo y | mkfs.ext4 -F -m 0 -L linuxroot "/dev/$DISK" >/dev/null 2>&1

    # tune filesystem
    tune2fs -o journal_data_writeback "/dev/$DISK" >/dev/null 2>&1
    tune2fs -O ^has_journal "/dev/$DISK" >/dev/null 2>&1
    e2fsck -yf "/dev/$DISK" >/dev/null 2>&1

    eval "$2=\$DISK"
}

#---------------------------------------------
# transfer system
#---------------------------------------------
transfer() {
    local size=$( du -s ${DIRS[@]} | awk 'BEGIN{sum=0}{sum+=$1}END{print sum}' )

    mkdir -p $OUTPUT/{proc,sys}

    (
        for dir in ${DIRS[@]}; do
            local processed=$(( $processed + $(du -s $dir | awk 'BEGIN{sum=0}{sum+=$1}END{print sum}') ))
            local pct=$(( $processed * 100 / $size ))
            local procent=${pct%.*}
            cp -ra $dir $OUTPUT/
            echo "XXX"
            echo "transfer directory:  $dir"
            echo "XXX"
            printf '%.0f\n' ${procent}
        done
    ) | dialog --title "Transfer system" --gauge "Copy system..." 6 60
}

#---------------------------------------------
# fix fstab/boot partition
#---------------------------------------------
fix_config() {
    if [[ ! -z $FIX_BOOT_DISK ]]; then
        [[ ! $(grep "$1" $OUTPUT/boot/uEnv.txt) ]] && ( echo "rootdev=/dev/$1" >> $OUTPUT/boot/uEnv.txt )
        [[ ! $(grep "^/dev/$1" $OUTPUT/etc/fstab) ]] && sed -i "s#^\/dev\/\([a-z0-9]*\)*#\/dev\/$1    #" $OUTPUT/etc/fstab
    fi
    sed -i '/^if*/,/^$/d' $OUTPUT/etc/issue
}

options+=("1" "system moving on the emmc or nand")
#options+=("2" "system moving on the nand")
#options+=("3" "system moving on the sata")

menu "system configuration" "\nselect one of the items" options[@] OUT

case "$OUT" in
    1) get_disks DISK ;;
#    2) get_disks DISK ;;
#    3)  get_disks DISK ;;
esac

msginfo "\nwait is disk preparation..."

prepare_disk "$DISK" OUT

DISK=$OUT

mount /dev/$DISK $OUTPUT

transfer

fix_config "$DISK"

umount $OUTPUT

rmdir $OUTPUT

msginfo "\nremove the memory card and restart the system"

