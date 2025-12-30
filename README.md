## How to Use Cylon CXL-SSD and Reproduce Experiments
To reduce the burden on the Artifact Evaluation (AE) committee, we provide a pre-configured Cylon environment hosted on CloudLab. The environment includes a virtual machine that emulates CXL-SSD functionality and is ready for experimentation.

### SSH Access to the Cylon VM

You can directly SSH into the Cylon virtual machine. please contact **Dongha Yoon** (`dongha@vt.edu`).

### Launching the Cylon VM
* In some cases (e.g., after an unexpected VM crash), you may need to manually launch the Cylon virtual machine.

1. SSH into the CloudLab host machine.
2. Start the Cylon VM: 
   ```sh
   cd Cylon/build-femu
   ./run-cxlssh.sh
   ```   
3. Pin CPUs (run in a separate terminal):
   ```sh
   cd Cylon/build-femu
   ./pin.sh
   ```

4. Initializing CXL-SSD Inside the VM
* Once the VM is running, initialize the CXL-SSD device inside the guest VM:
   ```sh
   bash ~/login.sh #ssh into the VM
   ./setup_dev.sh
   ```
* After initialization, the CXL-SSD appears as a CPU-less NUMA node:
   ```sh
   numactl -H
   # available: 2 nodes (0-1)
   # node 0 cpus: 0 1 2 3 4 5 6 7
   # node 0 size: 15991 MB
   # node 0 free: 7156 MB
   # node 1 cpus:
   # node 1 size: 65536 MB
   # node 1 free: 65536 MB
   # node distances:
   # node   0   1
   # 0:  10  20
   # 1:  20  10
   ```
* Or you can expose Cylon as an devdax device.
   ```sh
   # devdax mode
   daxctl reconfigure-device --mode=devdax --force dax0.0

   # systam-ram mode (CPU-less NUMA node)
   daxctl reconfigure-device --mode=system-ram --force dax0.0
   ```

### Reproducing Experiments
For reproducing experiments, please refer:
* [mlc](eval-mlc/experiments.md)
* [mio](eval-mio/experiments.md)
* [redis](eval-redis/experiments.md)
* [gapbs](eval-gapbs/experiments.md)


#### Which mode should I use for each benchmark?

Cylon can be exposed to the guest OS in **two mutually exclusive modes**:

- **system-ram**: the CXL-SSD capacity is hot-plugged into the Linux memory subsystem and shows up as a **CPU-less NUMA node**. Applications use it through normal `malloc()`/anonymous memory (often with `numactl --membind=<node>`).
- **devdax**: the capacity is exposed as a **DAX character device** (e.g., `/dev/dax0.0`). Applications must explicitly `mmap()` the DAX device (or use a PMem/DAX-aware library). It is *not* part of the normal page allocator.

| Benchmark | Required mode | Why |
|---|---|---|
| **Intel-MLC** | **system-ram** | MLC measures latency/bandwidth via normal memory allocations and NUMA placement; it cannot transparently use `/dev/dax*` without a DAX-specific harness. |
| **MIO** | **devdax** | The provided MIO experiments are intended to stress the memory tier via standard allocations/NUMA binding. Use **devdax** only if you are running a DAX-mmap variant explicitly described in `eval-mio/experiments.md`. |
| **Redis YCSB** | **system-ram** | Redis uses heap allocations (jemalloc/mimalloc/tcmalloc) and expects memory to come from the OS page allocator; it will not use `/dev/dax*` unless rewritten to mmap DAX. |
| **GAPBS** | **system-ram** |  |


> Rule of thumb: if the benchmark/application is unmodified and uses `malloc()` + `numactl`, you want **system-ram**. Use **devdax** only for benchmarks that explicitly open/mmap `/dev/dax*`.

### Support
If you encounter issues not covered in this document, please contact **Dongha Yoon** (`dongha@vt.edu`).
