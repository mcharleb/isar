inherit dpkg

python __anonymous() {
    DISTRO_NAME = d.getVar("DISTRO_NAME", True)
    DISTRO_ARCH = d.getVar("DISTRO_ARCH", True)
    ARCH_HOST = d.getVar("ARCH_HOST", True)

    ## Convert the POSIX architecture name to the Debian format
    def debian_architecture(machine):
        import re
        if re.match(r"x86[_-]64|i\d86[_-]64$", machine):
            return "amd64"
        elif re.match(r"i\d86$", machine):
            return "i386"
        elif re.match(r"armv", machine):
            return "armhf"

        return None

    ARCH_HOST_DEBIAN = debian_architecture(ARCH_HOST)
    d.setVar("ARCH_HOST_DEBIAN", ARCH_HOST_DEBIAN)

    ## Only "pure" Debian distributions support cross-building in ISAR,
    ## disable the feature if the distribution name is not "debian"
    if DISTRO_NAME != "debian" or ARCH_HOST_DEBIAN == DISTRO_ARCH or DISTRO_ARCH not in [ "armhf" ]:
        d.setVarFlag("do_crossbuild", "noexec", "1")
        return

    ## Disable the regular building task
    d.setVar("do_build", d.getVar("do_crossbuild", True))

    ## Remove "buildchroot" from the list of dependencies
    ## and add "crossbuildchroot" to it
    import re
    DEPENDS = d.getVar("DEPENDS", True)
    d.setVar("DEPENDS", re.sub(r"\bbuildchroot\b", "", DEPENDS) + " crossbuildchroot")

    PP = d.getVar("PP", True)
    CROSSBUILDCHROOT_DIR = d.getVar("CROSSBUILDCHROOT_DIR", True)
    BUILDROOT = CROSSBUILDCHROOT_DIR + PP
    d.setVar("BUILDROOT", BUILDROOT)

    d.setVarFlag("do_unpack", "dirs", BUILDROOT)
    #d.setVar("S", BUILDROOT)
}

do_crossbuild() {
    sudo chroot "${CROSSBUILDCHROOT_DIR}" /build.sh "${PP}/${SRC_DIR}" "${DISTRO_ARCH}"
}
