#!/bin/bash
# Huaicheng Li <huaicheng@cs.uchicago.edu>
# Run FEMU with no SSD emulation logic, (e.g., for SCM/Optane emulation)

# Image directory
IMGDIR=$HOME/images
# Virtual machine disk image
OSIMGF=$IMGDIR/ubuntu22.qcow2


if [[ ! -e "$OSIMGF" ]]; then
	echo ""
	echo "VM disk image couldn't be found ..."
	echo "Please prepare a usable VM image and place it as $OSIMGF"
	echo "Once VM disk image is ready, please rerun this script again"
	echo ""
	exit
fi

echo 0 | sudo tee /proc/sys/kernel/numa_balancing
echo 16384 | sudo tee /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled



#-object memory-backend-file,id=mem0,size=16G,mem-path=/dev/hugepages,prealloc=yes \
#-numa node,nodeid=0,memdev=mem0 \

sudo x86_64-softmmu/qemu-system-x86_64 \
    -name "FEMU-NoSSD-VM" \
    -enable-kvm \
    -cpu host \
    -smp 8 \
    -m 16G \
    -object memory-backend-ram,size=16384M,policy=bind,host-nodes=0,id=ram-node0,prealloc=on,prealloc-threads=8 \
    -numa node,nodeid=0,cpus=0-7,memdev=ram-node0 \
    --overcommit cpu-pm=on \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
    -device femu,devsz_mb=32768,id=nvme0,multipoller_enabled=1 \
    -net user,hostfwd=tcp::8080-:22 \
    -net nic,model=virtio \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait 2>&1 | tee log
