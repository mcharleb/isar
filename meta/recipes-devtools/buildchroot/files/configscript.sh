#!/bin/sh
#
# This software is a part of ISAR.
# Copyright (C) 2015-2017 ilbers GmbH

finish() {
  echo "------- finish ---------"
  # clean up the mounted filesystems
  ([ -f /proc/uptime ] && sudo umount /proc) || true
  ([ -c /dev/null ] && sudo umount /dev) || true
}
trap finish EXIT

set -e

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

#set up non-interactive configuration
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

#run pre installation script
echo "----- dash.preinst ----------"
/var/lib/dpkg/info/dash.preinst install

# apt-get http method, gpg require /dev/null
echo "----- mounting /dev ----------"
mount -t devtmpfs -o mode=0755,nosuid devtmpfs /dev

#configuring packages
dpkg --configure -a
echo "----- mounting /proc ----------"
mount proc -t proc /proc
dpkg --configure -a
rm -rf /var/lib/apt/lists/partial
rm -f /var/lib/apt/lists/*.bz2
apt-get update
umount /proc
umount /dev
