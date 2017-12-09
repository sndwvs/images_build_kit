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


case $(hostname) in
    *rk3*)
            START_LOADER=64
            LOADER=idbloader_mmc.img
    ;;
    cubietruck)
            START_LOADER=8
    ;;
    orange-pi-plus-2e)
            START_LOADER=8
    ;;
    *)
            exit
    ;;

esac


#echo $START_LOADER
#echo $OFFSET
#echo $(($OFFSET-1-$START_LOADER))

#dd if=/dev/$ROOT_DISK of=tt skip=$START_LOADER bs=$(($OFFSET-1-$START_LOADER)) count=1 conv=notrunc
#dd if=tt of=/dev/mmcblk1 seek=$START_LOADER
#dd if=$LOADER of=/dev/mmcblk1 seek=$START_LOADER
#exit

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

    # clear partition
    dd if=/dev/zero of=/dev/$DISK bs=1 count=64 seek=446 >/dev/null 2>&1

    # save u-boot
#    dd if=/boot/u-boot-sunxi-with-spl.bin of=/dev/$DISK bs=1024 seek=8 status=noxfer >/dev/null 2>&1

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
    [[ ! $(grep "$1" $OUTPUT/boot/uEnv.txt) ]] && ( echo "rootdev=/dev/$1" >> $OUTPUT/boot/uEnv.txt )
    [[ ! $(grep "^/dev/$1" $OUTPUT/etc/fstab) ]] && sed -i "s#^\/dev\/\([a-z0-9]*\)*#\/dev\/$1    #" $OUTPUT/etc/fstab
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

