FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Remove syslog as it is not required with systemd
SRC_URI:remove = "file://syslog.cfg"

# Provide the coreutils commands, as GNU coreutils is not installed anymore
SRC_URI:append = " file://coreutils-replacement.cfg"

busybox_cfg_variable() {
    CONF_SED_SCRIPT="$CONF_SED_SCRIPT /^CONFIG_$1[ =]/d;"
    if test "$2" = "n"; then
        echo "# CONFIG_$1 is not set" >> ${S}/.config
    else
        echo "CONFIG_$1=$2" >> ${S}/.config
    fi
}

do_prepare_config:append() {
    CONF_SED_SCRIPT=""

    # No need for klogd/syslogd as that is provided by systemd
    busybox_cfg_variable KLOGD n
    busybox_cfg_variable SYSLOGD n

    sed -i -e "${CONF_SED_SCRIPT}" ${S}/.config
}
