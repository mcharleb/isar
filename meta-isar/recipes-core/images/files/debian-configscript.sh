#!/bin/sh
#
# This software is a part of ISAR.
# Copyright (C) 2015-2017 ilbers GmbH

set -e

readonly MACHINE_SERIAL="$1"
readonly BAUDRATE_TTY="$2"
readonly ROOTFS_DEV="$3"
readonly DEBCACHEMNT="$4"
readonly DEBDISTRONAME="$5"

cat >> /etc/default/locale << EOF
LANG=en_US.UTF-8
LANGUAGE=en_US.UTF-8
LC_ALL=C
LC_CTYPE=C
EOF

## Configuration file for localepurge(8)
cat > /etc/locale.nopurge << EOF

# Remove localized man pages
MANDELETE

# Delete new locales which appear on the system without bothering you
DONTBOTHERNEWLOCALE

# Keep these locales after package installations via apt-get(8)
en
en_US
en_US.UTF-8
EOF

debconf-set-selections <<END
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8
locales locales/default_environment_locale select en_US.UTF-8
END

# Set up non-interactive configuration
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

# Run pre installation script
/var/lib/dpkg/info/dash.preinst install

# Configuring packages
dpkg --configure -a
mount proc -t proc /proc
dpkg --configure -a
umount /proc

echo "root:root" | chpasswd

cat > /etc/fstab << EOF
# Begin /etc/fstab
/dev/$ROOTFS_DEV	/		ext4		defaults		1	1
proc		/proc		proc		nosuid,noexec,nodev	0	0
sysfs		/sys		sysfs		nosuid,noexec,nodev	0	0
devpts		/dev/pts	devpts		gid=5,mode=620		0	0
tmpfs		/run		tmpfs		defaults		0	0
devtmpfs	/dev		devtmpfs	mode=0755,nosuid	0	0

# End /etc/fstab
EOF

# Create console device
if [ ! -e /dev/console ]; then
     mknod /dev/console c 5 1
fi

# Enable tty
printf 'T0:123:respawn:/sbin/getty -L %s %d vt100\n' $MACHINE_SERIAL $BAUDRATE_TTY >> /etc/inittab

# Undo setup script changes
if [ -x "$TARGET/sbin/start-stop-daemon.REAL" ]; then
    mv -f $TARGET/sbin/start-stop-daemon.REAL $TARGET/sbin/start-stop-daemon
fi

if [ -x "$TARGET/sbin/initctl.REAL" ]; then
    mv $TARGET/sbin/initctl.REAL $TARGET/sbin/initctl
fi

if [ -x "$TARGET/sbin/init" -a -x "$TARGET/usr/sbin/policy-rc.d" ]; then
    rm -f $TARGET/usr/sbin/policy-rc.d
fi

mkdir -p /etc/apt/sources.list.d/
cat <<EOF >/etc/apt/sources.list.d/${DEBDISTRONAME}.list
deb file:${DEBCACHEMNT}/ ${DEBDISTRONAME} main
deb-src file:${DEBCACHEMNT}/ ${DEBDISTRONAME} main
EOF
