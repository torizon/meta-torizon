SUMMARY = "Remote access client (RAC) for Torizon OS"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${S}/LICENSE;md5=34400b68072d710fecd0a2940a0d1658"

inherit cargo cargo-update-recipe-crates systemd useradd

# Main source respository
SRC_URI = " \
    git://github.com/torizon/rac.git;protocol=https;branch=main;name=rac \
    git://github.com/toradex/tough.git;protocol=https;branch=rac;name=tough;destsuffix=tough \
    file://remote-access.service \
    file://client.toml \
    file://sudoers.rac \
    file://migrate-rac-state.sh \
    file://rac-tmpfiles.conf \
"

SRCREV_FORMAT = "rac_tough"

SRCREV_rac = "c54d1d48c071db549ca8119cfd1f60f7c1c28127"
SRCREV_tough = "69e51d241b950951907b439a9996692967a9e82b"

# Track the latest revisions on head-next builds.
SRCREV_rac:use-head-next = "${AUTOREV}"
SRCREV_tough:use-head-next = "${AUTOREV}"

SYSTEMD_SERVICE:${PN} = "remote-access.service"

# RAC drops privileges to the rac user, which has full sudo access so that
# remote commands requiring root can run. The user is created here rather than
# in torizon-users so that the account, and its sudo rights, only exist on
# images that actually ship RAC.
USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "--system rac"
USERADD_PARAM:${PN} = "--system -g rac -d /home/rac -m -s /bin/sh rac"

# Remote commands are executed through sudo
RDEPENDS:${PN} += "sudo"

PV = "0.0+git${SRCPV}"

require ${BPN}-crates.inc

# Use --offline rather than --frozen mode with "cargo build".
#
# Due to the changes we needed to do in RAC Yocto recipe in order to use our toradex/tough registry,
# the tough repository got sort of aliased, so the upstream Git URL was in fact referencing our
# toradex/tough fork. Since this is a hack on top of Cargo, it got somewhat lost while parsing
# Cargo.lock and thought that the repository there needed to change to the upstream one to reflect
# the state of things.
#
CARGO_BUILD_FLAGS:remove = "--frozen"
CARGO_BUILD_FLAGS:append = " --offline"

# There is a postfunc that runs after do_configure. This fixing logic needs to run after this postfunc.
# It is because of this ordering this is do_compile:prepend instead of do_configure:append.
cargo_add_rac_patch_paths() {
    # Need to fix config file due to the tough repo having a virtual manifest.
    # Which is not supported by the cargo bbclasses currently,
    # see: https://github.com/openembedded/openembedded-core/commit/684a8af41c5bb70db68e75f72bdc4c9b09630810
    sed -i 's|tough =.*|tough = { path = "${UNPACKDIR}/tough/tough" }|g' ${CARGO_HOME}/config.toml
    sed -i '/olpc-cjson =.*/d' ${CARGO_HOME}/config.toml
    sed -i '/^tough =.*/a olpc-cjson = { path = "${UNPACKDIR}/tough/olpc-cjson" }' ${CARGO_HOME}/config.toml
}

do_configure[postfuncs] += "cargo_add_rac_patch_paths"

RUNRAC_FOLDER ??= "/home/rac/run/rac"

# The default RUNRAC_FOLDER changed from /home/torizon/run/rac (RAC running
# as the torizon user) to /home/rac/run/rac as part of TOR-4693. Keep track
# of the old default so migrate-rac-state.sh can move/re-own any pre-existing
# RAC state (device key, TUF trust root, SSH host keys) from an older RAC
# instead of leaving it torizon-owned or silently discarding it.
OLD_RUNRAC_FOLDER ??= "/home/torizon/run/rac"

do_install:append() {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${UNPACKDIR}/remote-access.service ${D}${systemd_unitdir}/system/remote-access.service
    sed -i "s|@@RUNRAC_FOLDER@@|${RUNRAC_FOLDER}|g" \
        ${D}${systemd_unitdir}/system/remote-access.service

    install -d ${D}${sysconfdir}/rac
    install -m 0644 ${UNPACKDIR}/client.toml ${D}${sysconfdir}/rac
    sed -i "s|@@RUNRAC_FOLDER@@|${RUNRAC_FOLDER}|g" \
        ${D}${sysconfdir}/rac/client.toml

    install -m 0755 -d ${D}${sysconfdir}/sudoers.d
    install -m 0440 ${WORKDIR}/sudoers.rac ${D}${sysconfdir}/sudoers.d/50-rac

    install -d ${D}${libexecdir}/rac
    install -m 0755 ${WORKDIR}/migrate-rac-state.sh ${D}${libexecdir}/rac/migrate-rac-state.sh
    sed -i \
        -e "s|@@RUNRAC_FOLDER@@|${RUNRAC_FOLDER}|g" \
        -e "s|@@OLD_RUNRAC_FOLDER@@|${OLD_RUNRAC_FOLDER}|g" \
        ${D}${libexecdir}/rac/migrate-rac-state.sh

    install -Dm 0644 ${S}/dbus/io.torizon.Rac1.conf ${D}${datadir}/dbus-1/system.d/io.torizon.Rac1.conf
    
    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${WORKDIR}/rac-tmpfiles.conf ${D}${nonarch_libdir}/tmpfiles.d/rac.conf
}

FILES:${PN} += " \
    ${nonarch_libdir}/tmpfiles.d/rac.conf \
    ${datadir}/dbus-1/system.d \
"
