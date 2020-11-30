# README #

to build images you need OS Slackware 14.2 or higher

project site: **[fail.pp.ua](http://fail.pp.ua)**  
**[images](http://dl.fail.pp.ua/slackware/images/)**  


# FAQ #

login: **root**  
password: **password**  


## support ARM based single-board computers ##
- - - -
* Allwinner
    * A20
        + [Cubietruck](https://linux-sunxi.org/Cubietech_Cubietruck)
    * H3
        + [Orange Pi Plus 2E](https://linux-sunxi.org/Xunlong_Orange_Pi_Plus_2E)
        + [Orange Pi PC](https://linux-sunxi.org/Xunlong_Orange_Pi_PC)
    * A64
        + [1080P Pinebook](https://wiki.pine64.org/index.php/1080P_Pinebook#SoC_and_Memory_Specification)
* Rockchip
    * RK3288
        + [Firefly-RK3288](http://en.t-firefly.com/product/rk3288.html)
    * RK3308
        + [Rock Pi S](https://wiki.radxa.com/RockpiS/getting_started#Features)
    * RK3328
        + [Rock64](http://wiki.pine64.org/index.php/ROCK64_Main_Page#SoC_and_Memory_Specification)
        + [Rock Pi E](https://wiki.radxa.com/RockpiE/getting_started#Features) board provided by [Radxa Team](https://forum.radxa.com/t/rock-pi-e-engineering-sample-is-available-now/3130)
        + [Station M1](http://stationpc.com/portal.php?mod=topic&topicid=7#spec) [(roc-rk3328-pc)](http://en.t-firefly.com/product/rocrk3328pc.html#spec)
    * RK3399
        + [Firefly-RK3399](http://en.t-firefly.com/product/rk3399.html)
        + [ROCKPro64](http://wiki.pine64.org/index.php/ROCKPro64_Main_Page#SoC_and_Memory_Specification)
        + [Rock Pi 4](http://rockpi.org/#spec-section)
        + [Pinebook Pro](https://wiki.pine64.org/index.php/Pinebook_Pro#SoC_and_Memory_Specification)
        + [Station P1](http://stationpc.com/portal.php?mod=topic&topicid=2#spec) [(roc-rk3399-pc-plus)](http://en.t-firefly.com/product/rocrk3399pc.html#spec)
        + [Helios64](https://wiki.kobol.io/helios64/intro/#overall-specifications)
* Broadcom
    * BCM2837
        + [Raspberry Pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
    * BCM2711
        + [Raspberry Pi 4](https://www.raspberrypi.org/products/raspberry-pi-4-model-b/specifications/) board provided by user [wowbaggerHU](https://www.linuxquestions.org/questions/user/wowbaggerhu-1042789/)
* Amlogic
    * S905X3
        + [Odroid-C4](https://wiki.odroid.com/odroid-c4/hardware/hardware#specifications)


# BUILD #

## cross compilation arm on aarch64 architecture ##
`ARCH=arm ./build.sh`


# VARIABLES #

## config/environment/00-environment.conf ##
| variable             | possible values      | description          |
| :------------------- | :------------------- | :------------------- |
| USE_NEXT_KERNEL_MIRROR | yes/no (yes - default) | use mainline kernel mirror |
| USE_UBOOT_MIRROR     | yes/no (no  - default) | use u-boot mirror  |
| USE_SLARM64_MIRROR   | yes/no (no  - default) | use slarm64 mirror |
| NTP                  | yes/no (yes - default) | setting up the NTP server |
| NETWORKMANAGER       | yes/no (yes - default) | setting up the NetworkManager service |
| IMAGE_COMPRESSION    | yes/no (yes - default) | image compression |
