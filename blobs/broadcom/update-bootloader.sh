#!/bin/bash

CWD=$(pwd)
NAME=firmware

git clone --depth=1 https://github.com/raspberrypi/firmware.git /tmp/${NAME} || exit 1

# Bootloader files for Raspberry Pi
if [[ -d $CWD/boot ]]; then
    rm -rf ${CWD}/boot/*.{bin,dat,elf}
else
    mkdir -p ${CWD}/boot
fi
cp /tmp/${NAME}/boot/{*.dat,*.bin,*.elf} ${CWD}/boot
[[ -d /tmp/${NAME} ]] && rm -rf /tmp/${NAME}
