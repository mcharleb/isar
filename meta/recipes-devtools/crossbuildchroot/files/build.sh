#!/bin/bash
#
# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

CROSSBUILDCHROOT_DIR="$1"
ARCH_HOST="$2"

set -e

# Go to build directory
cd "$CROSSBUILDCHROOT_DIR"

# Get list of dependencies manually. The package is not in apt, so no apt-get
# build-dep. dpkg-checkbuilddeps output contains version information and isn't
# directly suitable for apt-get install.
DEPS=$(env ARCH_HOST="${ARCH_HOST}" awk '$1 == "Build-Depends:" {
    gsub(/\([^)]+\)/, "", $0)
    gsub(/:[a-zA-Z0-9]+ \[/, ":", $0)
    gsub(/\]/, "", $0)
    n = split(substr($0, length("Build-Depends:")+1), a, ",")
    for (i=0; i < n; i++) {
        s = a[i]
        if (sub(/^.+:/, "", s) && s != ENVIRON["ARCH_HOST"] && s != "any" && s != "native")
            continue
        printf "%s", a[i]
    }
}' < debian/control)

if [ -n "${DEPS}" ]; then
    # Lock the crossbuildchroot before using `dpkg`
    readonly PATH_LOCK="../../../../tmp/crossbuild_deps_install.lock"
    while ! mkdir "${PATH_LOCK}" 2>/dev/null; do
        sleep 1
    done

    apt-get install -y $DEPS
fi

# If autotools files have been created, update their timestamp to
# prevent them from being regenerated                            
for i in configure aclocal.m4 Makefile.am Makefile.in; do        
    if [ -f "${i}" ]; then                                       
        touch "${i}"                                             
    fi                                                           
done                                                             

# Remove the lock to allow other packages to use `dpkg`
rm -r "${PATH_LOCK}"

# Build the package
dpkg-buildpackage -us -uc -a"$ARCH_HOST_DEBIAN"
