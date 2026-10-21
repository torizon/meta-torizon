SUMMARY = "Default aktualizr-torizon secondaries"
DESCRIPTION = "Configuration files to enable the secondaries pre-bundled with Torizon OS by default"
SECTION = "base"
LICENSE = "MPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MPL-2.0;md5=815ca599c9df247a0c7f619bab123dad"

inherit allarch

SRC_URI = " \
            file://50-secondaries.toml \
            file://secondaries.json \
            file://bl_actions.sh \
            file://common_actions.sh \
            "

S = "${UNPACKDIR}"

# Check if bootloader update is supported. Set it to "0" on machines whose
# bootloader is not updated through the U-Boot environment and the eMMC boot
# partitions (e.g. Qualcomm machines booting through UEFI/systemd-boot): the
# bootloader secondary and its handler are then not installed at all.
BL_UPDATE_SUPPORT ?= "1"

RDEPENDS:${PN} += "bash coreutils jq util-linux sed \
    ${@'mmc-utils u-boot-fw-utils' if d.getVar('BL_UPDATE_SUPPORT') == '1' else ''} \
"

DEPENDS += "${@'' if d.getVar('BL_UPDATE_SUPPORT') == '1' else 'jq-native'}"

do_install:append () {
    install -m 0700 -d ${D}${libdir}/sota/conf.d
    install -m 0644 ${UNPACKDIR}/50-secondaries.toml ${D}${libdir}/sota/conf.d/50-secondaries.toml
    install -m 0644 ${UNPACKDIR}/secondaries.json ${D}${libdir}/sota/secondaries.json
    sed -i "s/@@MACHINE@@/${MACHINE}/g" ${D}${libdir}/sota/secondaries.json

    if [ "${BL_UPDATE_SUPPORT}" != "1" ]; then
        # Drop the bootloader secondary ("torizon-generic", handled by bl_actions.sh)
        jq 'del(."torizon-generic")' ${D}${libdir}/sota/secondaries.json \
            > ${D}${libdir}/sota/secondaries.json.tmp
        mv ${D}${libdir}/sota/secondaries.json.tmp ${D}${libdir}/sota/secondaries.json
        chmod 0644 ${D}${libdir}/sota/secondaries.json
    fi

    if [ "${BL_UPDATE_SUPPORT}" = "1" ]; then
        install -d ${D}${bindir}
        install -m 0744 ${UNPACKDIR}/bl_actions.sh ${D}${bindir}/bl_actions.sh
        install -m 0644 ${UNPACKDIR}/common_actions.sh ${D}${bindir}/common_actions.sh
    fi
}

FILES:${PN} = " \
                ${libdir}/sota/conf.d/50-secondaries.toml \
                ${libdir}/sota/secondaries.json \
                ${bindir}/bl_actions.sh \
                ${bindir}/common_actions.sh \
                "
