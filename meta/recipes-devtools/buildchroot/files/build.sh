#!/bin/bash
#
# This software is a part of ISAR.
# Copyright (C) 2015-2017 ilbers GmbH

# Go to build directory
cd $1

# Get list of dependencies manually. The package is not in apt, so no apt-get
# build-dep. dpkg-checkbuilddeps output contains version information and isn't
# directly suitable for apt-get install.
DEPS=`perl -ne 'next if /^#/; $p=(s/^Build-Depends:\s*/ / or (/^ / and $p)); s/,|\n|\([^)]+\)|\[[^]]+\]//mg; print if $p' < debian/control`

# Lock the buildchroot before using `dpkg`
readonly PATH_LOCK="../../../../tmp/build_deps_install.lock"
while ! mkdir "${PATH_LOCK}" 2>/dev/null; do
    sleep 1
done

# Install deps
apt-get install -y $DEPS

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
dpkg-buildpackage -us -uc
