# [FAST'26] Cylon Artifact Evaluation
* The artifact consists of these 3 components.
    * [CylonFEMU](CylonFEMU/): Cylon's FEMU extension codebase
    * [CylonLinux](CylonFEMU/): Cylon's custom kernel for DER support
    * [Cylon-scripts](Cylon-scripts/): Benchmark and plot scripts

## How to Use Cylon CXL-SSD and Reproduce Experiments
To reduce the burden on the Artifact Evaluation (AE) committee, we provide a pre-configured Cylon environment hosted on CloudLab. The environment includes a virtual machine that emulates CXL-SSD functionality and is ready for experimentation.

### Launching the Cylon VM
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

### Configuring Cylon
* You can adjust Cylon configuration in `build-femu/run-cxlssd.sh` file.
#### Caching policy
```sh
# CXL-SSD DRAM buffer parameters
policy=2 # Replacement policy [1:LIFO 2:FIFO 3:S3FIFO 4:CLOCK]
prf_dg=0 # Next-n Prefetch degree
```

```sh
ssd_size=$1		# in MegaBytes
bufsz=$((ssd_size/20))
```
#### NAND timing
```sh
# Latency in nanoseconds
pg_rd_lat=40000      # NAND Read Latency (40us)
pg_wr_lat=200000     # NAND Write (program) Latency (200us)
blk_er_lat=2000000   # NAND Erase Latency (2ms)
ch_xfer_lat=0
```

## Reproducing Experiments
For reproducing experiments, please refer:
* [Intel MLC](Cylon-scripts/eval-mlc/README.md) (Figure 2, 4)
* [Mio](Cylon-scripts/eval-mio/README.md) (Figure 3, 6, 9, 10)
* [Redis](Cylon-scripts/eval-redis/README.md) (Figure 7, 11, 12)
* [GAPBS](Cylon-scripts/eval-gapbs/README.md) (Figure 8)


#### Which mode should I use for each benchmark?

Cylon can be exposed to the guest OS in **two mutually exclusive modes**:

- **system-ram**: the CXL-SSD capacity is hot-plugged into the Linux memory subsystem and shows up as a **CPU-less NUMA node**. Applications use it through normal `malloc()`/anonymous memory (often with `numactl --membind=<node>`).
- **devdax**: the capacity is exposed as a **DAX character device** (e.g., `/dev/dax0.0`). Applications must explicitly `mmap()` the DAX device (or use a PMem/DAX-aware library). It is *not* part of the normal page allocator.

    | Benchmark | Required mode |
    |---|---|
    | Intel-MLC | system-ram | 
    | MIO | devdax | 
    | Redis YCSB | system-ram | 
    | GAPBS | system-ram | 


> Rule of thumb: if the benchmark/application is unmodified and uses `malloc()` + `numactl`, you want **system-ram**. Use **devdax** only for benchmarks that explicitly open/mmap `/dev/dax*`.

## Support
If you encounter issues not covered in this document, please contact **Dongha Yoon** (`dongha@vt.edu`).
