# Copyright (C) 2017 Mark Charlebois
#
# Convert ext4 image to Android sparse image

inherit ext4-img

SIMG = "${DEPLOY_DIR_IMAGE}/${PN}.simg"
SIMG_ROOTFS = "${EXT4_IMAGE_FILE}"

do_simg () {
    img2simg ${SIMG_ROOTFS} ${SIMG}
}

addtask simg before do_build after do_ext4_image
