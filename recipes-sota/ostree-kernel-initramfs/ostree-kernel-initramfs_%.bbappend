PACKAGES:prepend = "ostree-devicetree-overlays "
ALLOW_EMPTY:ostree-devicetree-overlays = "1"
FILES:ostree-devicetree-overlays = "${nonarch_base_libdir}/modules/*/dtb/*.dtbo ${nonarch_base_libdir}/modules/*/dtb/overlays.txt"

# Overlays in OSTREE_DEVICETREE to be applied during boot time
OSTREE_DEVICETREE_OVERLAY_BOOT ?= ""

# The overlays.txt a BSP recipe deploys, with the BSP's default boot overlays; add that recipe's do_deploy to
# OSTREE_DTB_DEPENDS. The overlays in OSTREE_DEVICETREE_OVERLAY_BOOT are added to it, except for FIT images.
# If empty, overlays.txt lists only those in OSTREE_DEVICETREE_OVERLAY_BOOT, and FIT images install
# ${DEPLOY_DIR_IMAGE}/overlays.txt if there is one.
OSTREE_OVERLAYS_TXT ?= ""

# Prefix of the overlay configurations in the FIT image, e.g. "freescale_" for conf-freescale_<overlay>:
# with KERNEL_DTBVENDORED = "1", a configuration is named after the overlay's path in the kernel tree. It is
# added to the overlays.txt of FIT images, which the boot script reads from the deployment it boots: on a
# rollback, that script is the one of the newest deployment, and the FIT image of an older release has no prefix.
OSTREE_FIT_OVERLAYS_PREFIX ?= "${@(d.getVar('KERNEL_DTB_PREFIX') or '').replace('/', '_')}"

# Signed builds (tdx-signed) boot a FIT image built by TDX_KERNEL_FIT_RECIPE, and only image recipes and
# the boot script see KERNEL_IMAGETYPE = "fitImage": package that FIT image here too, not the plain kernel.
inherit ${@'tdx-kernel-fit-boot' if bb.utils.to_boolean(d.getVar('TDX_KERNEL_FIT')) else ''}

do_install:append () {
    if [ ${@ oe.types.boolean('${OSTREE_DEPLOY_DEVICETREE}')} = True ]; then
        # Overlays built during kernel compilation go in dtb/overlays/
        install -d $kerneldir/dtb/overlays
        if [ -n "$(find "$kerneldir/dtb/" -maxdepth 1 -type f -name "*.dtbo" | head -n1)" ]; then
            mv $kerneldir/dtb/*.dtbo $kerneldir/dtb/overlays/
        fi

        if [ -n "${OSTREE_OVERLAYS_TXT}" ]; then
            install -m 0644 ${OSTREE_OVERLAYS_TXT} $kerneldir/dtb/overlays.txt
            # Add each overlay once, on the fdt_overlays line: U-Boot imports overlays.txt as name=value
            # lines, and applying an overlay twice fails
            for dtbo in ${OSTREE_DEVICETREE_OVERLAY_BOOT}; do
                sed -n 's/^fdt_overlays=//p' $kerneldir/dtb/overlays.txt | tr ' ' '\n' | grep -qxF "$dtbo" ||
                    sed -i "s|^fdt_overlays=.*|& $dtbo|" $kerneldir/dtb/overlays.txt
            done
        else
            echo "fdt_overlays=$(echo ${OSTREE_DEVICETREE_OVERLAY_BOOT})" > "${DEPLOY_DIR_IMAGE}/overlays.txt"
            install -m 0644 ${DEPLOY_DIR_IMAGE}/overlays.txt $kerneldir/dtb
        fi

        # Fail the build, not the boot, when overlays.txt names an overlay the image does not ship
        for dtbo in $(sed -n 's/^fdt_overlays=//p' "$kerneldir/dtb/overlays.txt"); do
            if [ ! -e "$kerneldir/dtb/overlays/$dtbo" ]; then
                bbfatal "$dtbo is in overlays.txt but not installed in dtb/overlays/: build it with the kernel (KERNEL_DEVICETREE) or list it in OSTREE_DEVICETREE."
            fi
        done

    elif [ "${KERNEL_IMAGETYPE}" = "fitImage" ]; then
        overlays_txt="${OSTREE_OVERLAYS_TXT}"
        if [ -z "$overlays_txt" ]; then
            overlays_txt="${DEPLOY_DIR_IMAGE}/overlays.txt"
        fi
        if [ -e "$overlays_txt" ]; then
            install -d $kerneldir/dtb
            install -m 0644 "$overlays_txt" $kerneldir/dtb/overlays.txt
            if [ -n "${OSTREE_FIT_OVERLAYS_PREFIX}" ]; then
                # On a line of its own, also when the last line has no newline
                sed -i -e '$a\' $kerneldir/dtb/overlays.txt
                echo "fdt_overlays_prefix=${OSTREE_FIT_OVERLAYS_PREFIX}" >> $kerneldir/dtb/overlays.txt
            fi
        fi
    fi
}
OSTREE_DTB_DEPENDS ?= "${@'virtual/dtb:do_deploy' if d.getVar('PREFERRED_PROVIDER_virtual/dtb') else ''}"
do_install[depends] += "${OSTREE_DTB_DEPENDS}"
# The FIT image of signed builds must be deployed before it is installed
do_install[depends] += "${@d.getVar('TDX_KERNEL_FIT_DEPLOY') or ''}"
