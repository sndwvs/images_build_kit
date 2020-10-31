boards
├── cubietruck
│   ├── cubietruck.conf
│   └── motd
└── <board name>
    ├── <board name>.conf
    └── <welcome message>


| variable             | description          |
| :------------------: | :------------------: |
| BOARD_NAME           | board name in menu, image and hostname |
| SOCFAMILY            | rk3288, rk3308, rk3328, rk3399, sun7i, sun8i, sun50iw1, bcm2837, bcm2711, meson-sm1 |
| BOOT_LOADER_CONFIG   | config name u-boot |
| LINUX_CONFIG         | linux kernel config name in [kernel](../kernel) |
| LINUX_DEFCONFIG      | default linux kernel config name |
| DEVICE_TREE_BLOB     | hardware file name |
