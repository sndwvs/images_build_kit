#!/bin/bash

CWD=$(pwd)
NAME=firmware

git clone --depth=1 https://github.com/raspberrypi/firmware.git /tmp/${NAME} || exit 1

# Bootloader files for Raspberry Pi
[[ -d $CWD/boot ]] && rm -rf ${CWD}/boot
mkdir -p ${CWD}/boot
cp /tmp/${NAME}/boot/{*.dat,*.bin,*.elf} ${CWD}/boot
[[ -d /tmp/${NAME} ]] && rm -rf /tmp/${NAME}
