Base: qemu-8.0.50 and FEMU v8.0.0


References
  * https://github.com/vtess/FEMU
  * https://stevescargall.com/blog/2022/01/20/how-to-emulate-cxl-devices-using-kvm-and-qemu/
  * https://github.com/rajagond/pmem_cxl/blob/main/cxl_rnd2/README.md#how-to-emulate-cxl-using-qemu-and-kvm


Building
========

.. code-block:: shell

  mkdir build
  cd build

  cp ../femu-scripts/femu-copy-scripts.sh .
  ./femu-copy-scripts.sh .
  # only Debian/Ubuntu based distributions supported
  sudo ./pkgdep.sh

  ../configure --target-list=x86_64-softmmu --enable-kvm --enable-slirp 
  make -j all

Execution example
========

.. code-block:: shell

  sudo ~/qemu/build/qemu-system-x86_64 \
  -m 16G \ 
  -smp 16 \
  -machine type=q35,accel=kvm,nvdimm=on,cxl=on -enable-kvm \
  -nographic \
  -net nic,model=e1000 \
  -net user,hostfwd=tcp::2222-:22 \
  -hda ~/images/ubuntu22.qcow2 \
  -device femu,devsz_mb=1024,bufsz_mb=64,femu_mode=6,replacement=2,prefetch_degree=0,cxl_skip_ftl=0,id=femu-dev \
  -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1 \
  -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
  -device cxl-type3,bus=root_port13,femu=femu-dev,id=cxl-pmem0 \
  -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=32G


------

