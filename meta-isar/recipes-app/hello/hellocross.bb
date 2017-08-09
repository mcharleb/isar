# Sample application
#
# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

DESCRIPTION = "Sample cross compiled application for ISAR"

LICENSE = "gpl-2.0"
LIC_FILES_CHKSUM = "file://${LAYERDIR_isar}/licenses/COPYING.GPLv2;md5=751419260aa954499f7abaabaa882bbe"

PV = "0.1+g7f35942-1"

SRC_URI = "git://github.com/mcharleb/hellocross.git;protocol=https"
SRCREV = "4927cf1ce975a8617269020eb219a405b6872494"

SRC_DIR = "git"

inherit dpkg-cross
