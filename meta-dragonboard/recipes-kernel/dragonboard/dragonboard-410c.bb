# Dragonboard 410c Kernel
#
# Copyright (C) 2017 Mark Charlebois

inherit crossbuild

SRC_URI += "http://builds.96boards.org/snapshots/dragonboard410c/linaro/debian/latest/initrd.img-4.9.39-linaro-lt-qcom"

DEPENDS += "crossbuildchroot"

BUILDDIR="/home/builder/${PN}"

do_build() {

    rsync -avu --exclude=".git/" ${TOPDIR}/../kernel/kernel/ ${WORKDIR}/kernel
    mkdir -p ${CROSSBUILDCHROOT_DIR}${BUILDDIR}
    sudo mount --bind ${WORKDIR} ${CROSSBUILDCHROOT_DIR}${BUILDDIR}
    cat << EOF > ${WORKDIR}/do_build.sh
#!/bin/bash
export BUILDDIR=${BUILDDIR}
cd ${BUILDDIR}/kernel
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
make defconfig distro.config
make -j4 Image dtbs
EOF
    chmod 777 ${WORKDIR}/do_build.sh
    sudo chroot ${CROSSBUILDCHROOT_DIR} /home/builder/${PN}/do_build.sh
    sudo umount ${CROSSBUILDCHROOT_DIR}${BUILDDIR}

${TOPDIR}/../skales/dtbTool -o ${WORKDIR}/dt.img -s 2048 ${WORKDIR}/kernel/arch/arm64/boot/dts/qcom
export cmdline="root=/dev/ram0 rw rootwait console=ttyMSM0,115200n8"
${TOPDIR}/../skales/mkbootimg --kernel ${WORKDIR}/kernel/arch/arm64/boot/Image \
                   --ramdisk ${WORKDIR}/initrd.img-4.9.39-linaro-lt-qcom \
                   --output ${WORKDIR}/boot.img \
                   --dt ${WORKDIR}/dt.img \
                   --pagesize 2048 \
                   --base 0x80000000 \
                   --cmdline "$cmdline"

}
