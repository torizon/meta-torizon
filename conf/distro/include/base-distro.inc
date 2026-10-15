MAINTAINER = "Toradex Torizon OS Team <torizon.os@toradex.com>"

COPY_LIC_MANIFEST = "1"
COPY_LIC_DIRS = "1"

IMAGE_BASENAME_SUFFIX ?= ""

SDK_NAME_PREFIX = "${DISTRO}"
SDK_VERSION = "${DISTRO_VERSION}"

IMAGE_CLASSES:remove = "image_types_fsl"

# Torizon machine specific overrides
INHERIT += "torizon"

# This also disables the static packageconfig. runc needs to be dynamically
# linked for seccomp support. https://github.com/opencontainers/runc/issues/2008
PACKAGECONFIG:remove:pn-${PREFERRED_PROVIDER_virtual/runc} = "static"
PACKAGECONFIG:append:pn-${PREFERRED_PROVIDER_virtual/runc} = " seccomp"
PACKAGECONFIG:append:pn-${PREFERRED_PROVIDER_virtual/docker} = " seccomp"
PACKAGECONFIG:append:pn-systemd = " seccomp"

# SOTA
GARAGE_SIGN_TOOL = "uptane-sign"
OSTREE_OSNAME = "torizon"
OSTREE_MULTI_DEVICETREE_SUPPORT = "1"
SOTA_CLIENT_FEATURES:append = " ubootenv"
INITRAMFS_IMAGE = "initramfs-ostree-torizon-image"
INITRAMFS_FSTYPES = "cpio.gz"
BUILD_OSTREE_TARBALL = "0"
IMAGE_FSTYPES:remove:sota = "${IMAGE_FSTYPES_REMOVE}"

# No need to install boot script, kernel image, devicetrees or firmware into the boot partition
IMAGE_BOOT_FILES = ""
IMAGE_BOOT_FILES_REMOVE:sota = "boot.scr-${MACHINE};boot.scr overlays.txt overlays/*;overlays/"

DISTRO_FEATURES:append = " virtualization stateless-system apparmor"
DISTRO_FEATURES_REMOVE ?= "3g alsa irda pcmcia nfc ldconfig pulseaudio wayland x11 ptest multiarch vulkan"
DISTRO_FEATURES:remove = "${DISTRO_FEATURES_REMOVE}"

# Note, enable or disable the useradd-staticids in a configured system,
# the TMPDIR/DEPLOY_DIR/SSTATE_DIR may contain incorrect uid/gid values.
# Clearing them will correct this condition.
USERADDEXTENSION ?= "useradd-staticids"
USERADD_UID_TABLES ?= "files/torizon-static-passwd"
USERADD_GID_TABLES ?= "files/torizon-static-group"
USERADD_ERROR_DYNAMIC ?= "skip"

# machines where Torizon is experimental
EXPERIMENTALOVERRIDES = ""
# Currently Torizon does not support any experimental machines, in future such machines can be added like below:
#EXPERIMENTALOVERRIDES:colibri-imx6ull = ":experimental"
DISTROOVERRIDES .= "${EXPERIMENTALOVERRIDES}"

# Use our variant of the aktualizr client instead of the
# default from meta-updater
PREFERRED_PROVIDER_aktualizr = "aktualizr-torizon"
PREFERRED_PROVIDER_aktualizr-native = "aktualizr-torizon-native"
PREFERRED_RPROVIDER_aktualizr = "aktualizr-torizon"
PREFERRED_RPROVIDER_aktualizr-info = "aktualizr-torizon"
PREFERRED_RPROVIDER_aktualizr-shared-prov = "aktualizr-torizon"

# disable warning message from meta-security
SKIP_META_SECURITY_SANITY_CHECK = "1"

# Configure the "kernel command-line protection" for Torizon OS (relevant when
# the tdx-signed class is in use).
TOS_SECBOOT_REQUIRED_BOOTARGS_COMMON ?= "root=LABEL=otaroot rootfstype=ext4 ${OSTREE_KERNEL_ARGS}"
# Per-machine default bootargs for Torizon OS:
TOS_SECBOOT_REQUIRED_BOOTARGS_DEFAULT ?= "${TOS_SECBOOT_REQUIRED_BOOTARGS_COMMON}"
# Bootargs for Torizon OS; users of Torizon OS should override this one rather than
# TDX_SECBOOT_REQUIRED_BOOTARGS:
TOS_SECBOOT_REQUIRED_BOOTARGS ?= "${TOS_SECBOOT_REQUIRED_BOOTARGS_DEFAULT}"
# Override BSP configuration when tdx-signed is in use:
TDX_SECBOOT_REQUIRED_BOOTARGS:tdx-signed = "${TOS_SECBOOT_REQUIRED_BOOTARGS}"

# Export some extra build information (takes place if class image-buildinfo is used).
TDX_SIGNING_CLASS ?= ""
IMAGE_BUILDINFO_VARS:append = " TDX_SIGNING_CLASS OVERRIDES"

# create etc/build in the rootfs
INHERIT += "image-buildinfo"

# Log information on images and packages
INHERIT += "buildhistory"
BUILDHISTORY_COMMIT = "1"

IMAGE_LINGUAS ?= "en-us"

# Some Toradex recipes like linux-toradex, u-boot-toradex,
# device-tree-overlays are appending SCM hashes to PV, version
# numbers going backwards are not a problem as we don't provide
# binary feeds.
#
# This avoids some annoying errors as follows:
# | QA Issue: Package version went backwards which would break package feeds
ERROR_QA:remove = "version-going-backwards"

PACKAGECONFIG:append:pn-systemd = " serial-getty-generator"
PACKAGECONFIG:append:pn-qemu-native = " libusb"

# keep the dtb vendor directories in fitimage node names
KERNEL_DTBVENDORED = "1"

# This function changes the default tune for machines which
# are based on armv7a or armv7ve to use common tune value, note
# that we enforce hard-float which is default on Linux microPlatform.
# If you have one of those machines which are armv7a or armv7ve but
# can't support hard-float, please change tune = 'armv7athf' to
# tune = 'armv7at' below but then this is for your own distro.

def at_least_one(elements, list):
    for i in list:
        if i in elements:
            return True
    return False

def arm_tune_handler(d):
    armv7athf_tune_features = ['armv7a', 'armv7ve', 'cortexa5', 'cortexa7', 'cortexa9', 'cortexa15']
    armv8a_tune_features = ['armv8a', 'crc']
    features = d.getVar('TUNE_FEATURES').split()
    if at_least_one(armv7athf_tune_features, features):
        tune = 'armv7athf'
        if 'bigendian' in features:
            tune += 'b'
        if 'vfpv3' in features:
            tune += '-vfpv3'
        if 'vfpv3d16' in features:
            tune += '-vfpv3d16'
        if 'neon' in features:
            tune += '-neon'
        if 'vfpv4' in features:
            tune += '-vfpv4'
    elif at_least_one(armv8a_tune_features, features):
        # all currently used i.MX 8 members support the following
        tune = 'armv8a-crypto'
    else:
        tune = d.getVar('DEFAULTTUNE')
    return tune

DEFAULTTUNE := "${@arm_tune_handler(d)}"
