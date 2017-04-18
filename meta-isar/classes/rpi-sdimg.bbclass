# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

inherit ext4-img

do_rpi_sdimg () {
    if [ -d ${S}/boot ]; then
        rm -rf ${DEPLOY_DIR_IMAGE}/boot_rpi

        mkdir -p ${DEPLOY_DIR_IMAGE}/boot_rpi
        sudo mv ${S}/boot/* ${DEPLOY_DIR_IMAGE}/boot_rpi/
    fi
}

addtask rpi_sdimg before do_build after do_ext4_image
