require conf/distro/poky.conf
require base-distro.inc

IMAGE_CLASSES:append = " image_type_common_torizon"

# Override shared by all torizon distros
DISTROOVERRIDES .= ":common-torizon-distro"

# We do not need teziimg, ota-ext4 or wic images by default
IMAGE_FSTYPES_REMOVE ?= "wic.gz wic.bmap wic.xz"
BBMASK += " \
    /meta-arm/recipes-test/pacbti/test-pacbti.bb \
"

OSTREE_DEPLOY_DEVICETREE = "0"

hostname:pn-base-files ?= "${MACHINE}"

require conf/distro/include/versioning.inc

SDK_VENDOR = "-tznsdk"
SDK_NAME_PREFIX = "${DISTRO}"
# do not use elements in SDK_VERSION which are in vardepsexclude
SDK_VERSION = "${TDX_RELEASE}"

TARGET_VENDOR = "-tzn"

DISTRO_FEATURES:append = " pam systemd usrmerge"
DISTRO_FEATURES:remove = "sysvinit ptest"
VIRTUAL-RUNTIME_init_manager = "systemd"

PREFERRED_RPROVIDER_network-configuration = "networkmanager"

# Defines the root home directory as /root, as required by systemd.
ROOT_HOME = "/root"

# Apply BSP overrides after selecting the Common Torizon distro family.
require conf/machine/include/bsp-machine-overrides.inc
