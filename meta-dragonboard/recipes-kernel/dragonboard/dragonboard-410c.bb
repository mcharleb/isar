# Dragonboard 410c Kernel
#
# Copyright (C) 2017 Mark Charlebois

inherit custombuild

SRC_URI = "http://builds.96boards.org/snapshots/dragonboard410c/linaro/debian/latest/initrd.img-4.9.39-linaro-lt-qcom"
SRC_URI[md5sum] = "dd044fcd3960f5ec653a7e57a9601ce3"

#DEPENDS += "crossbuildchroot"

PAGESIZE="2048"

python do_unpack_append() {
    # Copy the linux kernel source
    workspace = d.getVar('WORKSPACE', True)
    workdir = d.getVar('WORKDIR', True)
    bb.plain("WORKSPACE = %s" % workspace)
    bb.plain("rsync -avu --exclude='.git/' %s/kernel/ %s/kernel" % (workspace, workdir))
    os.system("rsync -avu --exclude='.git/' %s/kernel/ %s/kernel" % (workspace, workdir))
}

do_build() {
    cd ${WORKDIR}/kernel
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    export PATH=${WORKSPACE}/gcc-linaro-4.9-2014.11-x86_64_aarch64-linux-gnu/bin:$PATH
    make defconfig distro.config
    make -j4 Image dtbs

    ${WORKSPACE}/skales/dtbTool -o ${WORKDIR}/dt.img -s ${PAGESIZE} ${WORKDIR}/kernel/arch/arm64/boot/dts/qcom

    export cmdline="root=/dev/ram0 rw rootwait console=ttyMSM0,115200n8"
    ${WORKSPACE}/skales/mkbootimg --kernel ${WORKDIR}/kernel/arch/arm64/boot/Image \
                   --ramdisk ${WORKDIR}/initrd.img-4.9.39-linaro-lt-qcom \
                   --output ${WORKDIR}/boot.img \
                   --dt ${WORKDIR}/dt.img \
                   --pagesize ${PAGESIZE} \
                   --base 0x80000000 \
                   --cmdline "$cmdline"

}
