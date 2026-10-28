SUMMARY = "Torizon OS default polkit rules"
DESCRIPTION = "Grants members of the torizon group the NetworkManager \
operations they could perform before polkitd was installed, and nominates \
the sudo group as polkit administrators"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://49-torizon-admin.rules \
    file://50-torizon.rules \
"

S = "${UNPACKDIR}"

EXCLUDE_FROM_WORLD = "1"
INHIBIT_DEFAULT_DEPS = "1"

inherit allarch features_check

REQUIRED_DISTRO_FEATURES = "polkit"

# The rules reference the torizon group, created by torizon-users, and are
# only read by polkitd.
RDEPENDS:${PN} = "polkit torizon-users"

do_install () {
    install -d ${D}${datadir}/polkit-1/rules.d
    install -m 0644 ${UNPACKDIR}/49-torizon-admin.rules ${D}${datadir}/polkit-1/rules.d/
    install -m 0644 ${UNPACKDIR}/50-torizon.rules ${D}${datadir}/polkit-1/rules.d/
}

FILES:${PN} = " \
    ${datadir}/polkit-1/rules.d/49-torizon-admin.rules \
    ${datadir}/polkit-1/rules.d/50-torizon.rules \
"
