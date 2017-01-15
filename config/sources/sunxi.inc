
FIRMWARE="firmware-overlay"

case "$KERNEL_SOURCE" in
    next)
            URL_LINUX_SOURCE="http://mirror.yandex.ru/pub/linux/kernel/v4.x"
            LINUX_SOURCE="linux-$(wget --no-check-certificate -qO- https://www.kernel.org/finger_banner | grep 'The latest stable' | awk '{print $NF}' | head -n1)"
    ;;
esac

URL_SUNXI_TOOLS="https://github.com/linux-sunxi"
SUNXI_TOOLS="sunxi-tools"
SUNXI_TOOLS_BRANCH="" #"v1.2"

BOOT_LOADER_BIN="u-boot-sunxi-with-spl.bin"

install_boot_script() {
    install -Dm644 $CWD/config/boot_scripts/boot.cmd "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"

    # orangepi h3 fix
    if [[ $SOCFAMILY == sun8i ]]; then
        # u-boot default is nonsec. Legacy requires sec, mainline requires nonsec for SMP
        local boot_mode=nonsec

        [[ $KERNEL_SOURCE == legacy ]] && boot_mode=sec
            sed -i -e "1s/^/gpio set PL10\ngpio set PG11\nsetenv machid 1029\nsetenv bootm_boot_mode $boot_mode\n/" \
                -e 's/\ disp.screen0_output_mode=1920x1080p60//' -e 's/\ hdmi.audio=EDID:0//' \
                "$CWD/$BUILD/$PKG/kernel-${SOCFAMILY}/boot/boot.cmd"
    fi
}
