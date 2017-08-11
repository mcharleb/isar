# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

# Add dependency from buildchroot creation
do_unpack[deptask] = "do_build"

do_fetch[dirs] = "${DL_DIR}"

# Fetch package from the source link
python do_fetch() {
    src_uri = (d.getVar('SRC_URI', True) or "").split()
    if len(src_uri) == 0:
        return

    try:
        fetcher = bb.fetch2.Fetch(src_uri, d)
        fetcher.download()
    except bb.fetch2.BBFetchException as e:
        raise bb.build.FuncFailed(e)
}

addtask fetch before do_build

do_unpack[dirs] = "${WORKDIR}"
do_unpack[stamp-extra-info] = "${DISTRO_ARCH}-${DISTRO}"
S ?= "${WORKDIR}"

# Unpack package and put it into working directory in buildchroot
python do_unpack() {
    src_uri = (d.getVar('SRC_URI', True) or "").split()
    if len(src_uri) == 0:
        return

    rootdir = d.getVar('WORKDIR', True)

    try:
        fetcher = bb.fetch2.Fetch(src_uri, d)
        fetcher.unpack(rootdir)
    except bb.fetch2.BBFetchException as e:
        raise bb.build.FuncFailed(e)
}

addtask unpack after do_fetch before do_build

do_build[stamp-extra-info] = "${DISTRO_ARCH}-${DISTRO}"

# Build package
do_build() {
	:
}

do_install[stamp-extra-info] = "${MACHINE}"

do_install() {
	:
}

addtask do_install after do_build

