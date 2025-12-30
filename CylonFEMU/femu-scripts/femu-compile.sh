#!/bin/bash

NRCPUS="$(cat /proc/cpuinfo | grep "vendor_id" | wc -l)"

make clean
# --disable-werror --extra-cflags=-w --disable-git-update
# AVX512 -> AVX256 -> SSE2 are the preferred methods to move NVMe data
../configure --enable-kvm --target-list=x86_64-softmmu --enable-slirp --extra-cflags="-mavx512f -mavx512dq -mavx512cd -mavx512bw -mavx512vl -mavx2"
make -j $NRCPUS

echo ""
echo "===> FEMU compilation done ..."
echo ""
exit
