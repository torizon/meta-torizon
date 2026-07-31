require recipes-bsp/u-boot/u-boot-fuse.inc
require recipes-bsp/u-boot/u-boot-rollback.inc
require recipes-bsp/u-boot/u-boot-tcb-sign.inc

# Path for the include file that genreates U-Boot OTA necessary JSON file
U_BOOT_OTA_INCLUDE = "recipes-bsp/u-boot/u-boot-ota.inc"
U_BOOT_OTA_INCLUDE:k3r5 = ""

require ${U_BOOT_OTA_INCLUDE}
