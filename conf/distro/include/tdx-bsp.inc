# Vendor identity
TARGET_VENDOR = "-tdx"
SDK_VENDOR = "-tdxsdk"

# Poky defaults to sysvinit (its own weak default beats OE-core's even
# weaker ??= fallback); pin Torizon OS to systemd explicitly.
INIT_MANAGER = "systemd"

# Distro features Torizon OS needs beyond base-distro.inc's own set
DISTRO_FEATURES:append = " opencl pam systemd-resolved tpm2 pni-names"

PREFERRED_PROVIDER_u-boot-fw-utils = "libubootenv"
PREFERRED_RPROVIDER_u-boot-fw-utils = "libubootenv"

# meta-toradex-bsp builds the devicetree overlays from the kernel tree, so they are in KERNEL_DEVICETREE and
# with it in OSTREE_DEVICETREE, and its overlays-txt recipe deploys overlays.txt with the default boot
# overlays (TEZI_EXTERNAL_KERNEL_DEVICETREE_BOOT): install that one, also for FIT images (e.g. signed builds).
OSTREE_OVERLAYS_TXT ?= "${DEPLOY_DIR_IMAGE}/overlays.txt"
OSTREE_DTB_DEPENDS:append = " overlays-txt:do_deploy"

PREFERRED_PROVIDER_opencl-headers:imxgpu      = "imx-gpu-viv"
PREFERRED_PROVIDER_opencl-clhpp:imxgpu        = "imx-gpu-viv"
PREFERRED_PROVIDER_opencl-icd-loader:imxgpu   = "imx-gpu-viv"
PREFERRED_RPROVIDER_opencl-icd-loader:imxgpu  = "libopencl-imx"

PREFERRED_RPROVIDER_libnss-mdns = "avahi-libnss-mdns"

# Show Tezi EULA license
TEZI_SHOW_EULA_LICENSE ?= "1"
TEZI_SHOW_EULA_LICENSE:use-mainline-bsp ?= "0"
TEZI_SHOW_EULA_LICENSE:colibri-imx6:use-mainline-bsp ?= "1"
TEZI_SHOW_EULA_LICENSE:apalis-imx6:use-mainline-bsp ?= "1"
