#!/bin/bash

RKBIN="../rkbin"

dd if=$RKBIN/rk33/rk3399_ddr_800MHz_v1.08.bin of=ddr.bin bs=4 skip=1
tools/mkimage -n rk3399 -T rksd -d ddr.bin idbloader.img
rm ddr.bin
cat $RKBIN/rk33/rk3399_miniloader_v1.06.bin >> idbloader.img
