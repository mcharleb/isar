# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

# Add dependency from buildchroot creation
DEPENDS += "buildchroot"
do_unpack[deptask] = "do_build"

# Each package should have its own unique build folder, so use
# recipe name as identifier
PP = "/home/builder/${PN}"
BUILDROOT = "${BUILDCHROOT_DIR}/${PP}"

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

do_unpack[dirs] = "${BUILDROOT}"
do_unpack[stamp-extra-info] = "${DISTRO}"
S ?= "${BUILDROOT}"

# Unpack package and put it into working directory in buildchroot
python do_unpack() {
    src_uri = (d.getVar('SRC_URI', True) or "").split()
    if len(src_uri) == 0:
        return

    rootdir = d.getVar('BUILDROOT', True)

    try:
        fetcher = bb.fetch2.Fetch(src_uri, d)
        fetcher.unpack(rootdir)
    except bb.fetch2.BBFetchException as e:
        raise bb.build.FuncFailed(e)
}

addtask unpack after do_fetch before do_build

do_build[stamp-extra-info] = "${DISTRO}"

# Build package from sources using build script
do_build() {
    sudo chroot ${BUILDCHROOT_DIR} /build.sh ${PP}/${SRC_DIR}
}

do_install[stamp-extra-info] = "${MACHINE}"

do_install() {
    readonly DIR_CACHE="${DEBCACHEDIR}/${DISTRO}"
    readonly DIR_DB="${DEBDBDIR}/${DISTRO}"

    if [ "${DEBCACHE_ENABLED}" != "0" ]; then
        # If `bitbake` is running for the first time, the cache doesn't exist
        # yet and needs to be configured using a `distributions` file
        # A template stored in the layer directory is pre-processed to generate
        # the configuration file, which is then placed in the appropriate directory
        if [ ! -e "${DIR_CACHE}/conf/distributions" ]; then
            mkdir -p "${DIR_CACHE}/conf"
            sed -e "s#{DISTRO_NAME}#${DEBDISTRONAME}#g" "${DEBFILESDIR}/distributions.in" \
                > "${DIR_CACHE}/conf/distributions"
        fi

        print_field_value() {
            awk "\$1 == \"${1}:\" { print \$2; }"
        }
        call_reprepro() {
            reprepro --waitforlock 3 -b "${DIR_CACHE}" --dbdir "${DIR_DB}" \
                -C main "$@"
        }

        # Add binary and source packages to the deb cache
        # If the cache doesn't exist yet, it will be created using the `distributions`
        # file generated above
        ls -1 "${BUILDROOT}"/*.deb | while read -r p; do
            name_package=$(dpkg -f "${p}" | print_field_value "Package")
            version_package=$(dpkg -f "${p}" | print_field_value "Version")

            ## Remove all packages with the same version that were added to the repository in previous builds
            call_reprepro -A "${DISTRO_ARCH}" removefilter "${DEBDISTRONAME}" "Package (== ${name_package}), Version (== ${version_package})"
            call_reprepro -A "${DISTRO_ARCH}" "include${p##*.}" "${DEBDISTRONAME}" "${p}"
        done

        ls -1 "${BUILDROOT}"/*.dsc | while read -r p; do
            name_package=$(cat "${p}" | print_field_value "Source")
            version_package=$(cat "${p}" | print_field_value "Version")

            ## Remove all source packages with the same version that were added to the repository in previous builds
            call_reprepro -A "source" removefilter "${DEBDISTRONAME}" "Package (== ${name_package}), Version (== ${version_package})"
            call_reprepro -A "source" "include${p##*.}" "${DEBDISTRONAME}" "${p}"
        done
    else
        # deb caching is disabled, simply copy all binary packages to the deploy directory
        mkdir -p "${DEPLOY_DIR_DEB}"
        ls -1 "${BUILDROOT}"/*.deb | while read -r p; do
            cp "${p}" "${DEPLOY_DIR_DEB}/"
        done
    fi
}

addtask do_install after do_build

# deb caching lambda run during the parsing phase that checks whether the current package has
# to be rebuilt, or taken from the cache
python __anonymous () {
    if d.getVar("DEBCACHE_ENABLED", True) == "0":
        # deb caching is disabled, do nothing
        return True

    PN = d.getVar("PN", True)
    PV = d.getVar("PV", True)
    DISTRO_ARCH = d.getVar("DISTRO_ARCH", True)
    DEBCACHEDIR = d.getVar("DEBCACHEDIR", True)
    DEBDISTRONAME = d.getVar("DEBDISTRONAME", True)
    DEBDBDIR = d.getVar("DEBDBDIR", True)
    DISTRO = d.getVar("DISTRO", True)
    path_cache = os.path.join(DEBCACHEDIR, DISTRO)
    path_databases = os.path.join(DEBDBDIR, DISTRO)
    path_distributions = os.path.join(path_cache, "conf", "distributions")

    # The distributions file is needed by `reprepro` to know what types
    # of packages are supported, what the distribution name is etc.
    # If it doesn't exist, we have nothing in the cache, do nothing
    if not os.path.exists(path_distributions):
        return

    import json

    # Anonymous functions are run several times under different contexts
    # during the parsing phase, which would let the code that follows be run
    # as many times for the same package
    # In order to guarantee that our subroutine only runs once per package,
    # we use bitbake's "persist" API in order to have reliable persistent
    # storage accross calls of the lambda (using a simple variable in the class
    # won't work, as several contexts won't allow fetching its value)
    pd = bb.persist_data.persist("DEBCACHE_PACKAGES", d)
    pd_json = {}

    if pd:
        try:
            pd_json = json.loads(pd)
        except ValueError:
            bb.warn("Cache possibly corrupted, ignoring")

    if DISTRO_ARCH not in pd:
        pd_json[DISTRO_ARCH] = {}
    if DISTRO not in pd_json[DISTRO_ARCH]:
        pd_json[DISTRO_ARCH][DISTRO] = {}
    if PN not in pd_json[DISTRO_ARCH][DISTRO]:
        pd_json[DISTRO_ARCH][DISTRO][PN] = []

    if PV in pd_json[DISTRO_ARCH][DISTRO][PN]:
        return

    import subprocess
    try:
        # The databases used by `reprepro` are not stored within the cache
        # in order to make versioning of only the files needed to use the cache
        # as an official Debian repository simpler
        # As such, if a developer uses a peer's cache to speed up their build time
        # but have never run bitbake, the database will not have been created,
        # so we regenerate them here
        if not os.path.exists(path_databases) and os.path.exists(path_cache):
            bb.note("Regenerating the cache databases...")
            subprocess.check_call([
                "reprepro",
                "--waitforlock", "3",
                "-b", path_cache,
                "--dbdir", path_databases,
                "export", DEBDISTRONAME,
            ])

        # Get a list of the versions of all the packages named after the current
        # bitbake package, and check whether the current package version is returned
        # As `reprepro` always returns zero with this particular operation, we
        # have to use this workaround to check for a package in the cache
        package_version = subprocess.check_output([
            "reprepro",
            "--waitforlock", "3",
            "-b", path_cache,
            "--dbdir", path_databases,
            "-C", "main",
            "-A", DISTRO_ARCH,
            "--list-format", "${version}",
            "list", DEBDISTRONAME, PN,
        ])
        package_version = package_version.decode("utf-8")
        if package_version == PV:
            # The below list contains the names of all the tasks are in charge
            # of building the package when the cache isn't enabled or if the package
            # hasn't been placed in it already
            # As all tasks are enabled by default, we prevent their execution by setting
            # the `noexec` flag, which will prevent a rebuild of the package when it's
            # cached
            for task in ["fetch", "unpack", "build", "install"]:
                d.setVarFlag("do_{}".format(task), "noexec", "1")
            d.setVar("DEPENDS", "")

            import re
            DEPENDS = d.getVar("DEPENDS", True)
            d.setVar("DEPENDS", re.sub(r"\bbuildchroot\b", "", DEPENDS))

            # Cache the results of this command so that subsequent executions of this
            # anonymous functions don't run the same code again
            pd_json[DISTRO_ARCH][DISTRO][PN].append(PV)
            pd = json.dumps(pd_json)
    except subprocess.CalledProcessError as e:
        bb.fatal("Unable to check for a candidate for package {0} (errorcode: {1})".format(PN, e.returncode))
}
