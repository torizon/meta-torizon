# bluetoothctl needs readline (GPL-3.0-or-later), which bluez cannot
# replace with libedit.
PACKAGECONFIG:remove = "readline"
