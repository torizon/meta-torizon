# udisks2 does not use the LVM, device-mapper and multipath plugins in Torizon
# OS, and they pull in lvm2, whose helper scripts need GNU coreutils (GPLv3).
PACKAGECONFIG:remove = "lvm lvm-dbus dm mpath"
