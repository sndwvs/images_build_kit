#!/bin/bash


patching_kernel_sources (){
#--------------------------------------------------------------------------------------------------------------------------------
# patching kernel sources
#--------------------------------------------------------------------------------------------------------------------------------
#    message "" "patching" "kernel $LINUX_SOURCE"

P="/home.old/0/patch/lib-master/patch/kernel/sun7i-default"
K="/home.old/0/build/source/linux-sunxi/"

    cd $K

    for _patch in $(ls $P | grep ".patch$" | grep -v "disable"); do
        echo ${_patch}
        if [ "$(patch --dry-run -t -p1 < $P/${_patch} | grep Reversed)" == "" ]; then
            echo "${_patch}" >> patch.log
#            patch  --batch -f -p1 < $P/${_patch} || exit 1
        fi
    done
    exit

    if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch | grep Reversed)" == "" ]; then
        patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch || exit 1
    fi



    if [[ "$BOARD_NAME" == "cubietruck" ]];then
        # mainline
        if [[ "$KERNEL_SOURCE" == "next" ]];then
            #   [ 11.822938] eth0: device MAC address 86:d7:74:ee:31:69
            #   [ 11.828080] libphy: PHY stmmac-0:ffffffff not found
            #   [ 11.832956] eth0: Could not attach to PHY
            #   [ 11.836963] stmmac_open: Cannot attach to PHY (error: -19)
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch || exit 1
            fi

            # sun4i: spi: Allow transfers larger than FIFO size
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/03_spi_allow_transfer_larger.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/03_spi_allow_transfer_larger.patch || exit 1
            fi

            # fix BRCMFMAC AP mode Banana & CT
#            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/brcmfmac_ap_banana_ct.patch | grep Reversed)" == "" ]; then
#                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/brcmfmac_ap_banana_ct.patch || exit 1
#            fi

            # fix BRCMF and MMC if copy big data to WIFI
            # http://forum.armbian.com/index.php/topic/230-cubietruck-armbian-42-cubietruck-debian-jessie-416-wifi-does-not-work/
            # https://groups.google.com/forum/#!msg/linux-sunxi/v6Ktt8lAnw0/T9gOChygom0J
#            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/brcmf_mmc_copy_big_data.patch | grep Reversed)" == "" ]; then
#                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/brcmf_mmc_copy_big_data.patch || exit 1
#            fi
        else
        # sunxi 3.4
        #    rm $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/drivers/spi/spi-sun7i.c
        #    rm -r $CWD/$BUILD/$SOURCE/$LINUX_SOURCE/drivers/net/wireless/ap6210/

            # wireless ap6210
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/0030-ap6210_module-cubietruck.patch | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/0030-ap6210_module-cubietruck.patch || exit 1
            fi

            # SPI functionality
#            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/spi.patch | grep previ)" == "" ]; then
#                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/spi.patch || exit 1
#            fi

            # Aufs3
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/linux-sunxi-3.4.108-overlayfs.patch | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/linux-sunxi-3.4.108-overlayfs.patch || exit 1
            fi

            # More I2S and Spdif
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/i2s_spdif_sunxi.patch | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/i2s_spdif_sunxi.patch || exit 1
            fi

            # A fix for rt8192
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/rt8192cu-missing-case.patch | grep Reversed)" == "" ]; then
                patch --batch -f -p1 < $CWD/patch/$BOARD_NAME/rt8192cu-missing-case.patch || exit 1
            fi
        fi
    elif [[ "$BOARD_NAME" == "firefly" ]];then
        if [[ "$KERNEL_SOURCE" == "next" ]];then
            #   [ 11.822938] eth0: device MAC address 86:d7:74:ee:31:69
            #   [ 11.828080] libphy: PHY stmmac-0:ffffffff not found
            #   [ 11.832956] eth0: Could not attach to PHY
            #   [ 11.836963] stmmac_open: Cannot attach to PHY (error: -19)
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/01_fix_tx_normaldesc.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/01_fix_tx_normaldesc.patch || exit 1
            fi

            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/02_fix_no_phy_found_regression.patch || exit 1
            fi

#            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/03_dts_remove_broken-cd_from_emmc_and_sdio.patch | grep Reversed)" == "" ]; then
#                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/03_dts_remove_broken-cd_from_emmc_and_sdio.patch || exit 1
#            fi
            # The rtc hym8563 maybe failed to register if first startup or rtc
            # powerdown:
            # [    0.988540 ] rtc-hym8563 1-0051: no valid clock/calendar values available
            # [    0.995642 ] rtc-hym8563 1-0051: rtc core: registered hym8563 as rtc0
            # [    1.078985 ] rtc-hym8563 1-0051: no valid clock/calendar values available
            # [    1.085698 ] rtc-hym8563 1-0051: hctosys: unable to read the hardware clock
            if [ "$(patch --dry-run -t -p1 < $CWD/patch/$BOARD_NAME/04_rtc_hym8563_make_sure_hym8563_can_be_normal_work.patch | grep Reversed)" == "" ]; then
                patch  --batch -f -p1 < $CWD/patch/$BOARD_NAME/04_rtc_hym8563_make_sure_hym8563_can_be_normal_work.patch || exit 1
            fi
        fi
    fi
}


patching_kernel_sources

