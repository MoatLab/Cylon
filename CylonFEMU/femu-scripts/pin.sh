#!/bin/bash
# Huaicheng Li <huaicheng@cs.uchicago.edu>
# pin vcpu and qemu main thread to certain set of physical CPUs
#

NRCPUS="$(cat /proc/cpuinfo | grep "vendor_id" | wc -l)"

# pin vcpus (use at most 36 pCPUs)
sudo ./ftk/qmp-vcpu-pin -s ./qmp-sock 2 3 4 5 6 7 8 9 #$(seq 30 47) $(seq 24 29)

# pin FEMU poller thread
POLLCPU=29
for poller in $(grep FEMU-NVMe-Poller-TID log | awk -F:\  '{print $3}'); do
    FEMU_POLLER_TID=$poller
    [[ -z $FEMU_POLLER_TID ]] && echo -e "\t===> FEMU NVMe Poller thread ID not found from log file..." && exit
    echo -e "===> Pinning FEMU NVMe poller thread to pCPU: $POLLCPU"
    sudo taskset -cp ${POLLCPU} $FEMU_POLLER_TID
    ((POLLCPU-=1))
done


# pin main thread to the rest of pCPUs
#qemu_pid=$(ps -ef | grep qemu | grep -v grep | tail -n 1 | awk '{print $2}')

#sudo taskset -cp 1-$NRCPUS ${qemu_pid}
