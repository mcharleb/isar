inherit dpkg

DEPENDS_remove = "buildchroot"
DEPENDS += "crossbuildchroot"
BUILDROOT = "${CROSSBUILDCHROOT_DIR}/${PP}"

do_unpack[dirs] = "${BUILDROOT}"
S ?= "${BUILDROOT}"

do_build() {
    sudo chroot "${CROSSBUILDCHROOT_DIR}" /build.sh "${PP}/${SRC_DIR}" "${DISTRO_ARCH}"
}
