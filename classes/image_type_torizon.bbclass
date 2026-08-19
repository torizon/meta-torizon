inherit image_type_tezi

TEZI_ROOT_LABEL = "otaroot"
TEZI_ROOT_NAME = "ota"
TEZI_ROOT_SUFFIX = "ota.tar.zst"
TEZI_USE_BOOTFILES = "false"

MINIMUM_TORIZON_TEZI_CONFIG_FORMAT = "3"
# Check if BSP's TEZI_CONFIG_FORMAT is higher than the one we need. If it is, we use BSP's value
python() {
    bsp_tezi = d.getVar('TEZI_CONFIG_FORMAT')
    torizon_tezi = d.getVar('MINIMUM_TORIZON_TEZI_CONFIG_FORMAT')
    if int(bsp_tezi) < int(torizon_tezi):
        d.setVar('TEZI_CONFIG_FORMAT', torizon_tezi)
}

# Enable verity on the filesystem when composefs is selected.
TEZI_ROOT_FSOPTS:append:cfs-signed = " -O verity"

python adjust_tezi_artifacts() {
    artifacts = d.getVar('TEZI_ARTIFACTS').replace(d.getVar('KERNEL_IMAGETYPE'), '').replace(d.getVar('KERNEL_DEVICETREE'), '')
    d.setVar('TEZI_ARTIFACTS', artifacts)
}

TCB_SIGNING_FILES_TARBALL = "tcb_signing_files.tar.gz"
TCB_SIGNING_SUPPORT ?= "0"

pack_tcb_signing_binaries_in_teziimg() {
    if [ "${TCB_SIGNING_SUPPORT}" != "1" ]; then
        # TorizonCore Builder signing support feature not enabled
        return 0
    fi

    if [ "${TDX_IMX_HAB_ENABLE}" != "1" ]; then
        bbwarn "TCB signing support enabled but HAB support is disabled. Skipping."
        return 0
    fi

    if [ "${UBOOT_SIGN_ENABLE}" != "1" ]; then
        bbwarn "TCB signing support enabled but signed kernel FIT image generation is disabled. Skipping."
        return 0
    fi

    if [ -z "${TCB_SIGNING_FILELIST}" ]; then
        bbwarn "TCB signing support enabled but TCB_SIGNING_FILELIST is empty (MACHINE likely not supported). Skipping."
        return 0
    fi

    bbnote "Packing TorizonCore Builder signing files"

    # Here we explicitly change to DEPLOY_DIR_IMAGE because the shell tries to expand filenames
    # with wildcards (e.g. with asterisk) before running the tar command, so they're relative
    # to the directory the tar command was called (the shell doesn't know that tar will grab
    # the files from somewhere else)
    (cd "${DEPLOY_DIR_IMAGE}" && tar --preserve-permissions --dereference \
        -czf "${WORKDIR}/${TCB_SIGNING_FILES_TARBALL}" ${TCB_SIGNING_FILELIST})

    cp "${WORKDIR}/${TCB_SIGNING_FILES_TARBALL}" \
       "${IMGDEPLOYDIR}/${TCB_SIGNING_FILES_TARBALL}"
}

python add_signing_files_to_tezi_artifacts() {
    signing_files_path = d.getVar('WORKDIR') + '/' + d.getVar('TCB_SIGNING_FILES_TARBALL')

    if os.path.isfile(signing_files_path):
        d.appendVar('TEZI_ARTIFACTS', ' ' + signing_files_path)
}

TEZI_IMAGE_TEZIIMG_PREFUNCS:append = " add_signing_files_to_tezi_artifacts adjust_tezi_artifacts"

require torizon_base_image_type.inc

TEZI_IMAGE_TEZIIMG_PREFUNCS:prepend = "gen_torizon_prov_data pack_tcb_signing_binaries_in_teziimg "

do_image_teziimg[cleandirs] += "${WORKDIR}/prov-data"
do_image_teziimg[vardeps] += "${TORIZON_IMG_VARDEPS}"
do_image_teziimg[file-checksums] += "${TORIZON_IMG_FILE_CHECKSUMS}"
do_image_teziimg[depends] += "${TORIZON_IMG_DEPENDS}"
