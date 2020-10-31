```
boards
├── cubietruck
│   ├── cubietruck.conf
│   └── motd
└── <board name>
    ├── <board name>.conf
    └── <welcome message>
```


| variable             | description          |
| :------------------- | :------------------- |
| BOARD_NAME           | board name in menu, image and hostname |
| SOCFAMILY            | [rk3288](../sources/rk3288.conf), [rk3308](../sources/rk3308.conf), [rk3328](../sources/rk3328.conf), [rk3399](../sources/rk3339.conf), [sun7i](../sources/sun7i.conf), [sun8i](../sources/sun8i.conf), [sun50iw1](../sources/sun50iw1.conf), [bcm2837](../sources/bcm2837.conf), [bcm2711](../sources/bcm2711.conf), [meson-sm1](../sources/meson-sm1.conf) |
| BOOT_LOADER_CONFIG   | config name u-boot |
| LINUX_CONFIG         | linux kernel config name in [kernel](../kernel) |
| LINUX_DEFCONFIG      | default linux kernel config name |
| DEVICE_TREE_BLOB     | hardware file name |
