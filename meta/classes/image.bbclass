# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

KERNEL_IMAGE ?= ""
INITRD_IMAGE ?= ""

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
