#!/bin/bash

CWD=$(pwd)

#export PATH=$PWD/gcc-linaro-4.8-2015.06-x86_64_aarch64-elf/bin:$PWD/gcc-linaro-4.8-2015.06-x86_64_arm-linux-gnueabi/bin:$PATH

echo -e "\n>>>>> download toolchain\n"
#wget -c https://releases.linaro.org/archive/13.11/components/toolchain/binaries/gcc-linaro-aarch64-none-elf-4.8-2013.11_linux.tar.xz
#wget -c https://releases.linaro.org/archive/13.11/components/toolchain/binaries/gcc-linaro-arm-none-eabi-4.8-2013.11_linux.tar.xz
wget -c https://releases.linaro.org/components/toolchain/binaries/4.9-2016.02/aarch64-elf/gcc-linaro-4.9-2016.02-x86_64_aarch64-elf.tar.xz
wget -c https://releases.linaro.org/components/toolchain/binaries/4.9-2016.02/arm-eabi/gcc-linaro-4.9-2016.02-x86_64_arm-eabi.tar.xz
wget -c https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
tar xfJ gcc-linaro-4.9-2016.02-x86_64_aarch64-elf.tar.xz
tar xfJ gcc-linaro-4.9-2016.02-x86_64_arm-eabi.tar.xz
tar xfJ gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
#export PATH=$PWD/gcc-linaro-aarch64-none-elf-4.8-2013.11_linux/bin:$PWD/gcc-linaro-arm-none-eabi-4.8-2013.11_linux/bin:$PATH
export PATH=$PWD/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin:$PWD/gcc-linaro-4.9-2016.02-x86_64_aarch64-elf/bin:$PWD/gcc-linaro-4.9-2016.02-x86_64_arm-eabi/bin:$PATH

echo -e "\n>>>>> download mainline u-boot\n"
DIR_MAINLINE=$CWD/odroid-c4-mainline
if [[ ! -d $DIR_MAINLINE ]]; then
git clone --depth 1 \
    https://gitlab.denx.de/u-boot/u-boot.git $DIR_MAINLINE || exit 1
fi
cd $DIR_MAINLINE
git clean -xdfq && git reset --hard
export CROSS_COMPILE=aarch64-none-linux-gnu-
make clean
for pth in $(ls $CWD/../../patch/u-boot/meson-sm1/* | LC_ALL=C sort -u);do
    echo "patching " ${pth##*/}
    patch -p1 -i ${pth} || exit 1
done
make odroid-c4_defconfig
make -j4

cd $CWD

echo -e "\n>>>>> download vendor u-boot\n"
DIR=$CWD/odroid-c4
if [[ ! -d $DIR ]]; then
git clone --depth 1 \
   https://github.com/hardkernel/u-boot.git -b odroidg12-v2015.01 \
   $DIR || exit 1
fi
cd $DIR || exit 1
git clean -xdfq && git reset --hard 

# fixed CROCC_COMPILE prefix
sed 's:aarch64-none-elf:aarch64-elf:g' -i Makefile
find -name Makefile -exec sed 's:arm-none-eabi:arm-eabi:g' -i {} \+

make clean
for pth in $(ls $CWD/../../patch/u-boot-tools/meson-sm1/* | LC_ALL=C sort -u);do
    if [[ ! $pth =~ 'fixed-compiler-names' ]]; then
        echo "patching " ${pth##*/}
        patch -p1 -i ${pth} || exit 1
    fi
done

make odroidc4_defconfig || exit 1
make -j4 || exit 1

export UBOOTDIR=$PWD
cd $DIR_MAINLINE
mkdir fip

wget -c https://github.com/BayLibre/u-boot/releases/download/v2017.11-libretech-cc/blx_fix_g12a.sh -O fip/blx_fix.sh
echo -e "\n>>>>> copy vendor firmware\n"
cp $UBOOTDIR/build/scp_task/bl301.bin fip/ || exit 1
cp $UBOOTDIR/build/board/hardkernel/odroidc4/firmware/acs.bin fip/ || exit 1
cp $UBOOTDIR/fip/g12a/bl2.bin fip/ || exit 1
cp $UBOOTDIR/fip/g12a/bl30.bin fip/ || exit 1
cp $UBOOTDIR/fip/g12a/bl31.img fip/ || exit 1
cp $UBOOTDIR/fip/g12a/ddr3_1d.fw fip/ || exit 1
cp $UBOOTDIR/fip/g12a/ddr4_1d.fw fip/ || exit 1
cp $UBOOTDIR/fip/g12a/ddr4_2d.fw fip/ || exit 1
cp $UBOOTDIR/fip/g12a/diag_lpddr4.fw fip/ || exit 1
cp $UBOOTDIR/fip/g12a/lpddr3_1d.fw fip/
cp $UBOOTDIR/fip/g12a/lpddr4_1d.fw fip/ || exit 1
cp $UBOOTDIR/fip/g12a/lpddr4_2d.fw fip/ || exit 1
cp $UBOOTDIR/fip/g12a/piei.fw fip/ || exit 1
cp $UBOOTDIR/fip/g12a/aml_ddr.fw fip/ || exit 1
cp u-boot.bin fip/bl33.bin || exit 1

echo -e "\n>>>>> create bl30\n"
sh fip/blx_fix.sh \
    fip/bl30.bin \
    fip/zero_tmp \
    fip/bl30_zero.bin \
    fip/bl301.bin \
    fip/bl301_zero.bin \
    fip/bl30_new.bin \
    bl30 || exit 1

echo -e "\n>>>>> create bl2\n"
sh fip/blx_fix.sh \
    fip/bl2.bin \
    fip/zero_tmp \
    fip/bl2_zero.bin \
    fip/acs.bin \
    fip/bl21_zero.bin \
    fip/bl2_new.bin \
    bl2 || exit 1

echo -e "\n>>>>> aml_encrypt_g12a step 1\n"
$UBOOTDIR/fip/g12a/aml_encrypt_g12a --bl30sig --input fip/bl30_new.bin \
                                    --output fip/bl30_new.bin.g12a.enc \
                                    --level v3 || exit 1

echo -e "\n>>>>> aml_encrypt_g12a step 2\n"
$UBOOTDIR/fip/g12a/aml_encrypt_g12a --bl3sig --input fip/bl30_new.bin.g12a.enc \
                                    --output fip/bl30_new.bin.enc \
                                    --level v3 --type bl30 || exit 1
echo -e "\n>>>>> aml_encrypt_g12a step 3\n"
$UBOOTDIR/fip/g12a/aml_encrypt_g12a --bl3sig --input fip/bl31.img \
                                    --output fip/bl31.img.enc \
                                    --level v3 --type bl31 || exit 1
echo -e "\n>>>>> aml_encrypt_g12a step 4\n"
$UBOOTDIR/fip/g12a/aml_encrypt_g12a --bl3sig --input fip/bl33.bin --compress lz4 \
                                    --output fip/bl33.bin.enc \
                                    --level v3 --type bl33 --compress lz4 || exit 1
echo -e "\n>>>>> aml_encrypt_g12a step 5\n"
$UBOOTDIR/fip/g12a/aml_encrypt_g12a --bl2sig --input fip/bl2_new.bin \
                                    --output fip/bl2.n.bin.sig || exit 1
echo -e "\n>>>>> aml_encrypt_g12a step 6\n"
$UBOOTDIR/fip/g12a/aml_encrypt_g12a --bootmk \
            --output fip/u-boot.bin \
            --bl2 fip/bl2.n.bin.sig \
            --bl30 fip/bl30_new.bin.enc \
            --bl31 fip/bl31.img.enc \
            --bl33 fip/bl33.bin.enc \
            --ddrfw1 fip/ddr4_1d.fw \
            --ddrfw2 fip/ddr4_2d.fw \
            --ddrfw3 fip/ddr3_1d.fw \
            --ddrfw4 fip/piei.fw \
            --ddrfw5 fip/lpddr4_1d.fw \
            --ddrfw6 fip/lpddr4_2d.fw \
            --ddrfw7 fip/diag_lpddr4.fw \
            --ddrfw8 fip/aml_ddr.fw \
            --ddrfw9 fip/lpddr3_1d.fw \
            --level v3 || exit 1

echo -e "\n>>>>> build complite\n"

