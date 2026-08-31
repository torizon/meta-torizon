# Vendor identity (was inherited from meta-toradex-distro's tdx-base.inc)
TARGET_VENDOR = "-tdx"
SDK_VENDOR = "-tdxsdk"

# Poky defaults to sysvinit (its own weak default beats OE-core's even
# weaker ??= fallback); pin Torizon OS to systemd explicitly.
INIT_MANAGER = "systemd"

# Distro features Torizon OS needs beyond base-distro.inc's own set
DISTRO_FEATURES:append = " opencl pam systemd-resolved tpm2 pni-names"

PREFERRED_PROVIDER_u-boot-fw-utils = "libubootenv"
PREFERRED_RPROVIDER_u-boot-fw-utils = "libubootenv"

# Default virtual/dtb provider for NXP i.MX8/i.MX9 vendor-BSP builds.
PREFERRED_PROVIDER_virtual/dtb ?= "device-tree-overlays-imx"

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
