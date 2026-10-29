SUMMARY = "Set the rollback mode of Aktualizr-Torizon"
DESCRIPTION = "Configures how aktualizr-torizon cooperates with the bootloader to detect rollbacks"
SECTION = "base"
LICENSE = "MPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MPL-2.0;md5=815ca599c9df247a0c7f619bab123dad"

# The rollback mode depends on the machine's bootloader.
PACKAGE_ARCH = "${MACHINE_ARCH}"

# U-Boot machines, and GRUB machines through the fw_printenv/fw_setenv shims of
# grub-ota-fallback, arm the rollback through the upgrade_available/bootcount
# environment ("uboot_masked").
#
# With systemd-boot the rollback is done by the bootloader itself: OSTree
# writes boot-counting BLS entries, greenboot gates boot-complete.target and
# systemd-bless-boot marks the entry good; after the tries are exhausted
# systemd-boot boots the previous deployment. aktualizr must not touch any
# bootloader environment there ("none"); it still reports a failed install
# when the booted deployment is not the one it installed.
AKTUALIZR_ROLLBACK_MODE ?= "${@'none' if d.getVar('OSTREE_BOOTLOADER') == 'systemd-boot' else 'uboot_masked'}"

S = "${UNPACKDIR}"

do_install() {
    install -m 0700 -d ${D}${libdir}/sota/conf.d
    printf '[bootloader]\nrollback_mode = "%s"\n' "${AKTUALIZR_ROLLBACK_MODE}" \
        > ${D}${libdir}/sota/conf.d/30-rollback.toml
    chmod 0644 ${D}${libdir}/sota/conf.d/30-rollback.toml
}

FILES:${PN} = " \
    ${libdir}/sota/conf.d/30-rollback.toml \
"
