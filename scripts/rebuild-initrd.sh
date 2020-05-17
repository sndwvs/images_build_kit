#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

KERNEL_VERSION=$(uname -r)
INITRD_MODULES="ext4:xfs:btrfs"
INITRD_NAME="uInitrd"
MESSAGES+=("kernel")
MESSAGES+=("modules")


case $(uname -m) in
    arm*) KARCH="arm" ;;
    aarch64) KARCH="arm64" ;;
esac


read_param() {
    local READ="$1"
    local MSG="$2"
    local QUESTION="$3"
    read -e -p "select ${MSG}: " -i ${QUESTION} ${READ}
}

# backup uInitrd
[[ -f ${INITRD_NAME}-${KERNEL_VERSION} ]] && cp ${INITRD_NAME}-${KERNEL_VERSION} ${INITRD_NAME}-${KERNEL_VERSION}.$(date +'%Y%m%d%H%M')

for msg in ${MESSAGES[*]}; do
    [[ $msg == "kernel" ]] && PARAM=${KERNEL_VERSION}
    [[ $msg == "modules" ]] && PARAM=${INITRD_MODULES}
    read_param line ${msg} ${PARAM}
    [[ $msg == "kernel" && ! -z ${line%% *} ]] && KERNEL_VERSION=${line%% *} && PARAM=${KERNEL_VERSION}
    [[ $msg == "modules" && ! -z ${line%% *} ]] && INITRD_MODULES=${line%% *} && PARAM=${INITRD_MODULES}
    echo "${msg}: ${PARAM}"
done

echo "Started build ${INITRD_NAME}-${KERNEL_VERSION}"

mkinitrd -R -L -u -w 2 -c -k ${KERNEL_VERSION} -m ${INITRD_MODULES} \
         -s /tmp/initrd-tree -o /tmp/initrd.gz

pushd "/tmp/initrd-tree/" || exit 1
echo "initrd-${KERNEL_VERSION}" > "/tmp/initrd-tree/initrd-name" || exit 1
find . | cpio --quiet -H newc -o | gzip -9 -n > "/tmp/initrd-${KERNEL_VERSION}.img" || exit 1
popd

mkimage -A $KARCH -O linux -T ramdisk -C gzip -n ${INITRD_NAME} -d "/tmp/initrd-${KERNEL_VERSION}.img" "/boot/uInitrd-${KERNEL_VERSION}" || exit 1
rm -rf /tmp/initrd* || exit 1

if [[ ! -z $(mount | grep -P "mmcblk0p1.*media.*fat") ]]; then
    cp -a "/boot/${INITRD_NAME}-${KERNEL_VERSION}" "/boot/${INITRD_NAME}" || exit 1
else
    ln -sf "/boot/${INITRD_NAME}-${KERNEL_VERSION}" -r "/boot/${INITRD_NAME}" || exit 1
fi

echo -e "\nRebuild ${INITRD_NAME}-${KERNEL_VERSION} complited.\n"
