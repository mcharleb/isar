# Root filesystem for packages building
#
# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

DESCRIPTION = "Multistrap cross-development environment"

LICENSE = "gpl-2.0"
LIC_FILES_CHKSUM = "file://${LAYERDIR_isar}/licenses/COPYING.GPLv2;md5=751419260aa954499f7abaabaa882bbe"

PV = "1.0"

CROSSBUILDCHROOT_PREINSTALL += " \
                           gcc \
                           build-essential \
                           make \
                           debhelper \
                           autotools-dev \
                           dpkg \
                           locales \
                           docbook-to-man \
                           apt \
                           automake \
                           crossbuild-essential-${DISTRO_ARCH} \
"

WORKDIR = "${TMPDIR}/work/${PF}/${DISTRO_ARCH}/${DISTRO}"

def debian_architecture():
    import platform, re
    machine = platform.uname().machine
    if re.match(r"x86[_-]64|i\d86[_-]64", machine):
        return "amd64"
    elif re.match(r"i\d86", machine):
        return "i386"
    elif re.match(r"armv", machine):
        return "armhf"

    return None

ARCH_HOST ?= "${@debian_architecture()}"

do_build[stamp-extra-info] = "${DISTRO_ARCH}-${DISTRO}"

do_build() {
    install -d -m 755 ${WORKDIR}/hooks_multistrap

    # Copy config files
    install -m 644 ${THISDIR}/files/multistrap.conf.in ${WORKDIR}/multistrap.conf
    install -m 755 ${THISDIR}/files/configscript.sh ${WORKDIR}
    install -m 755 ${THISDIR}/files/setup.sh ${WORKDIR}
    install -m 755 ${THISDIR}/files/download_dev-random ${WORKDIR}/hooks_multistrap/

    # Adjust multistrap config
    sed -i 's|##CROSSBUILDCHROOT_PREINSTALL##|${CROSSBUILDCHROOT_PREINSTALL}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO##|${DISTRO}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO_ARCH##|${DISTRO_ARCH}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##ARCH_HOST##|${ARCH_HOST}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO_APT_SOURCE##|${DISTRO_APT_SOURCE}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO_SUITE##|${DISTRO_SUITE}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO_COMPONENTS##|${DISTRO_COMPONENTS}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##CONFIG_SCRIPT##|./tmp/work/${PF}/${DISTRO_ARCH}/${DISTRO}/configscript.sh|' ${WORKDIR}/multistrap.conf
    sed -i 's|##SETUP_SCRIPT##|./tmp/work/${PF}/${DISTRO_ARCH}/${DISTRO}/setup.sh|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DIR_HOOKS##|./tmp/work/${PF}/${DISTRO_ARCH}/${DISTRO}/hooks_multistrap|' ${WORKDIR}/multistrap.conf

    # Multistrap config use relative paths, so ensure that we are in the right folder
    cd ${TOPDIR}

    # Create root filesystem
    sudo multistrap -a ${ARCH_HOST} -d "${CROSSBUILDCHROOT_DIR}" -f "${WORKDIR}/multistrap.conf" || true

    # Install package builder script
    sudo install -m 755 ${THISDIR}/files/build.sh "${CROSSBUILDCHROOT_DIR}"

    # Configure root filesystem
    sudo chroot ${CROSSBUILDCHROOT_DIR} /configscript.sh
}
