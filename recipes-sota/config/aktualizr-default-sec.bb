SUMMARY = "Default aktualizr-torizon secondaries"
DESCRIPTION = "Configuration files to enable the secondaries pre-bundled with Torizon OS by default"
SECTION = "base"
LICENSE = "MPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MPL-2.0;md5=815ca599c9df247a0c7f619bab123dad"

inherit allarch

SRC_URI = " \
            file://50-secondaries.toml \
            file://secondaries.json \
            file://dummy_actions.sh \
            "

S = "${UNPACKDIR}"

DEPENDS = "jq-native"

# A registered secondary must stay registered: Torizon Cloud rejects an ECU that disappears
# and returns. Machine defaults come from the BSP; local.conf can override them.
TORIZON_SECONDARY_DOCKER_COMPOSE ?= "1"
TORIZON_SECONDARY_BOOTLOADER ?= "${TORIZON_SECONDARY_BOOTLOADER_DEFAULT}"
TORIZON_SECONDARY_FUSES ?= "${TORIZON_SECONDARY_FUSES_DEFAULT}"
TORIZON_SECONDARY_BOOTLOADER_DEFAULT ??= ""
TORIZON_SECONDARY_FUSES_DEFAULT ??= "0"

BOOTLOADER_ACTION_HANDLER ??= "dummy_actions.sh"
FUSE_ACTION_HANDLER ??= "dummy_actions.sh"

python () {
    # Multiconfigs with a distro other than Torizon OS never build this recipe.
    if not bb.utils.contains('DISTRO_FEATURES', 'sota', True, False, d):
        raise bb.parse.SkipRecipe('needs the sota distro feature')

    machine = d.getVar('MACHINE')

    if d.getVar('BL_UPDATE_SUPPORT') is not None:
        bb.fatal(
            'BL_UPDATE_SUPPORT is set, but it no longer has any effect. '
            'Whether an image registers the bootloader secondary is now set by '
            'TORIZON_SECONDARY_BOOTLOADER ("1" or "0"), and the handler it gets by '
            'BOOTLOADER_ACTION_HANDLER_TYPE ("dummy" or "uboot-emmc"). '
            'Remove BL_UPDATE_SUPPORT; keep TORIZON_SECONDARY_BOOTLOADER at "1" for devices '
            'that have registered the bootloader ECU (and select the handler type), or at '
            '"0" if they have never registered it.')

    handler_note = ' The BSP selects the bootloader handler independently of registration.'
    for var, secondary, note in (('TORIZON_SECONDARY_DOCKER_COMPOSE', 'docker-compose', ''),
                                 ('TORIZON_SECONDARY_BOOTLOADER', 'bootloader', handler_note),
                                 ('TORIZON_SECONDARY_FUSES', 'fuses', '')):
        value = d.getVar(var) or ''
        if value in ('0', '1'):
            continue
        # Firmware multiconfigs (such as TI's k3r5) parse this recipe too, for machines without
        # values, and never build it.
        if not value and d.getVar('BB_CURRENT_MC'):
            raise bb.parse.SkipRecipe('%s is not set in multiconfig %s'
                                      % (var, d.getVar('BB_CURRENT_MC')))
        state = 'not set' if not value else 'set to "%s"' % value
        bb.fatal(
            '%s is %s for MACHINE "%s". Set it to "1" to register the %s secondary, as '
            'Torizon OS has done so far, or to "0" not to, in local.conf or, with "?=", in '
            'the machine configuration. A device that has registered the secondary needs '
            '"1" in every later image: Torizon Cloud rejects an ECU that disappears and '
            'comes back.%s' % (var, state, machine, secondary, note))
}

do_install:append () {
    install -m 0700 -d ${D}${libdir}/sota/conf.d
    install -m 0644 ${UNPACKDIR}/50-secondaries.toml ${D}${libdir}/sota/conf.d/50-secondaries.toml

    # Drop the secondaries this image does not register. Entries this recipe does not know (a
    # layer's own secondaries.json may add some) pass through.
    keep=""
    drop=""
    if [ "${TORIZON_SECONDARY_DOCKER_COMPOSE}" = "1" ]; then
        keep="$keep docker-compose=TORIZON_SECONDARY_DOCKER_COMPOSE"
    else
        drop="$drop docker-compose"
    fi
    if [ "${TORIZON_SECONDARY_BOOTLOADER}" = "1" ]; then
        keep="$keep ${MACHINE}-bootloader=TORIZON_SECONDARY_BOOTLOADER"
        if [ "${BOOTLOADER_ACTION_HANDLER}" = "dummy_actions.sh" ]; then
            install -d ${D}${bindir}
            install -m 0744 ${UNPACKDIR}/dummy_actions.sh ${D}${bindir}/dummy_actions.sh
            # Existing secondaries.json copies name this path, including those in /etc/sota.
            ln -s dummy_actions.sh ${D}${bindir}/bl_actions.sh
        fi
    else
        drop="$drop ${MACHINE}-bootloader"
    fi
    if [ "${TORIZON_SECONDARY_FUSES}" = "1" ]; then
        keep="$keep ${MACHINE}-fuses=TORIZON_SECONDARY_FUSES"
        if [ "${FUSE_ACTION_HANDLER}" = "dummy_actions.sh" ]; then
            install -d ${D}${bindir}
            install -m 0744 ${UNPACKDIR}/dummy_actions.sh ${D}${bindir}/dummy_actions.sh
            ln -s dummy_actions.sh ${D}${bindir}/fuse_actions.sh
        fi
    else
        drop="$drop ${MACHINE}-fuses"
    fi

    # Only list sections hold ECU entries; others, such as aktualizr's "IP", pass through.
    sed -e "s/@@MACHINE@@/${MACHINE}/g" ${UNPACKDIR}/secondaries.json |
        jq --arg drop "$drop" \
           'map_values(if type == "array"
                       then map(select(.ecu_hardware_id as $id
                                       | ($drop | split(" ") | index($id)) == null))
                       else . end)
            | with_entries(select(.value != []))' > ${UNPACKDIR}/secondaries-kept.json

    # A secondaries.json from another layer may lack an entry: the device would drop that ECU.
    for entry in $keep; do
        id=${entry%%=*}
        n=$(jq --arg id "$id" \
               '[.[] | arrays | .[] | objects | select(.ecu_hardware_id == $id)] | length' \
               ${UNPACKDIR}/secondaries-kept.json)
        if [ "$n" != "1" ]; then
            if [ "$n" = "0" ]; then
                if [ "$id" = "${MACHINE}-fuses" ]; then
                    hint=". On i.MX, images built before this change added that entry themselves, even"
                    hint="$hint to a layer's own file, so devices have registered it."
                else
                    hint=", or, if devices have never registered this secondary, set"
                    hint="$hint ${entry#*=} = \"0\"."
                fi
                hint=". If a layer provides its own secondaries.json, copy the entry from the one in meta-torizon$hint"
            else
                hint=". Remove the extra copies of this entry."
            fi
            bbfatal "secondaries.json lists the $id secondary $n times, but this image" \
                "registers it, so it must be listed exactly once$hint"
        fi
    done
    install -m 0644 ${UNPACKDIR}/secondaries-kept.json ${D}${libdir}/sota/secondaries.json
}

FILES:${PN} = " \
                ${libdir}/sota/conf.d/50-secondaries.toml \
                ${libdir}/sota/secondaries.json \
                ${bindir}/bl_actions.sh \
                ${bindir}/fuse_actions.sh \
                ${bindir}/dummy_actions.sh \
                "
