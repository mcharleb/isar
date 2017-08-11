#!/bin/bash

if [ ! -d gcc-linaro-4.9-2014.11-x86_64_aarch64-linux-gnu ]; then
    wget http://releases.linaro.org/archive/14.11/components/toolchain/binaries/aarch64-linux-gnu/gcc-linaro-4.9-2014.11-x86_64_aarch64-linux-gnu.tar.xz
    tar tvJf gcc-linaro-4.9-2014.11-x86_64_aarch64-linux-gnu.tar.xz
    rm gcc-linaro-4.9-2014.11-x86_64_aarch64-linux-gnu.tar.xz
fi
if [ ! -d skales ]; then
    git clone git://codeaurora.org/quic/kernel/skales 
fi
if [ ! -d kernel ]; then
    git clone -n --depth 1 -b ubuntu-qcom-dragonboard410c-15.07 http://git.linaro.org/landing-teams/working/qualcomm/kernel.git
    cd kernel
    git checkout -b kernel-15.07 ubuntu-qcom-dragonboard410c-15.07
fi
