# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

def get_image_name(d, name_link):
    S = d.getVar("S", True)
    path_link = os.path.join(S, name_link)
    if os.path.exists(path_link):
        return os.path.basename(os.path.realpath(path_link))

    return ""

KERNEL_IMAGE = "${@get_image_name(d, 'vmlinuz')}"
INITRD_IMAGE = "${@get_image_name(d, 'initrd.img')}"

IMAGE_INSTALL ?= ""
IMAGE_TYPE    ?= "ext4-img"

inherit ${IMAGE_TYPE}

do_populate[stamp-extra-info] = "${MACHINE}"

# Install Debian packages from the cache
do_populate() {
    readonly DIR_CACHE="${DEBCACHEDIR}/${DISTRO}"

    if [ -n "${IMAGE_INSTALL}" ]; then
        if [ "${DEBCACHE_ENABLED}" != "0" ]; then
            sudo mkdir -p "${S}/${DEBCACHEMNT}"
            sudo mount -o bind "${DIR_CACHE}" "${S}/${DEBCACHEMNT}"

            sudo chroot "${S}" apt-get update -y
            for package in ${IMAGE_INSTALL}; do
                sudo chroot "${S}" apt-get install -t "${DEBDISTRONAME}" -y --allow-unauthenticated "${package}"
            done

            sudo umount "${S}/${DEBCACHEMNT}"
        else
            sudo mkdir -p ${S}/deb

            for p in ${IMAGE_INSTALL}; do
                find "${DEPLOY_DIR_DEB}" -type f -name '*.deb' -exec \
                    sudo cp '{}' "${S}/deb/" \;
            done

            sudo chroot ${S} /usr/bin/dpkg -i -R /deb

            sudo rm -rf ${S}/deb
        fi
    fi
}

addtask populate before do_build
do_populate[deptask] = "do_install"

python do_update_boot_options() {
    KERNEL_IMAGE = d.getVar("KERNEL_IMAGE", True)
    if not KERNEL_IMAGE:
        d.setVar("KERNEL_IMAGE", get_image_name(d, "vmlinuz"))

    INITRD_IMAGE = d.getVar("INITRD_IMAGE", True)
    if not INITRD_IMAGE:
        d.setVar("INITRD_IMAGE", get_image_name(d, "initrd.img"))
}

addtask do_update_boot_options after do_populate
