#!/bin/bash

. /usr/libexec/greenboot/greenboot-logs

if fw_printenv rollback >/dev/null 2>&1; then
    ROLLBACK=$(fw_printenv rollback | cut -d '=' -f 2)
elif ls /boot/loader/entries/*+0-*.conf >/dev/null 2>&1; then
    # systemd-boot: an entry with exhausted boot counting was rolled back
    ROLLBACK=1
fi

# if we are in the rollback state, warn the user
if [ "$ROLLBACK" == "1" ]; then
    log_to_console "The last update failed and you are in a rollback state."
    if [ -e "$LOGFILE" ]; then
        log_to_console "Please check the logs in $LOGFILE for more information."
    else
        log_to_console "Unfortunately the logs are unavailable, probably because the update failed before starting userspace applications."
    fi
else
    rm -Rf "$LOGFILE"
fi
