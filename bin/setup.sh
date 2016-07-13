#!/bin/bash

set -e


#---------------------------------------------
# configuration
#---------------------------------------------
DIRS=("/bin" "/boot" "/dev" "/etc" "/lib" "/media" "/opt" "/root" "/run" "/sbin" "/tmp" "/var")
#DIRS=("/bin" "/boot" "/dev" "/etc" "/home" "/lib" "/media" "/mnt" "/opt" "/root" "/run" "/sbin" "/srv" "/swap" "/tmp" "/usr" "/var")
OUTPUT="./set"
#OUTPUT="/prepare"


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
    disks=($(lsblk | awk '{ if ($6 == "disk" && $1 !~ /boot/)  print $1}'))

    local options

    for disk in "${disks[@]}"; do
        options+=("$disk" "select disk for install")
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
    #dd if=/dev/zero of=/dev/$DISK bs=1M count=10 >/dev/null 2>&1

    # save u-boot
    #dd if=/boot/u-boot-sunxi-with-spl.bin of=/dev/$DISK bs=1024 seek=8 status=noxfer >/dev/null 2>&1

    #echo -e "\nn\np\n1\n2048\n\nw" | fdisk "/dev/$DISK" >/dev/null 2>&1

    if [[ $DISK =~ mmc* ]] ;then
        DISK=${DISK}p1
    else
        DISK=${DISK}1
    fi

    #echo y | mkfs.ext4 "/dev/$DISK" >/dev/null 2>&1
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
    ) | dialog --title "Transfer system" --gauge "Copy files..." 6 60
}


options+=("1" "system moving on the emmc")
options+=("2" "system moving on the nand")
#options+=("3" "system moving on the sata")


#msg "trye title" "test\nrr4\t"
menu "system configuration" "\nselect one of the items" options[@] OUT

case "$OUT" in
    1) get_disks DISK ;;
#    2) get_disks DISK ;;
#    3)  get_disks DISK ;;
esac

#echo $DISK
#msg "WARNING" "create partition on disk\n\n/dev/$DISK"

msginfo "\nwait is disk preparation..."

prepare_disk "$DISK" OUT
DISK=$OUT

mount /dev/$DISK $OUTPUT
exit
transfer
exit

umount $OUTPUT
rmdir $OUTPUT

msg "WARNING" "reboot your systen now"
