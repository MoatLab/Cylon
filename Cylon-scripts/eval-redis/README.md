# Run Experiments

Since redis will use Cylon as default system-ram, make sure Cylon mode is system-ram by running
```sh
daxctl reconfigure-device --mode=system-ram --force dax0.0
```

### Figure 7
This experiments is to compare the latency of Cylon vs CMM-H in Redis YCSB Workload-C.
* To run and generate the same plot as Figure 7, run it with:
```bash
ENABLE_PRELOAD=1 RUN_TAG=cylon-1t ./run-figure7.sh
```

* You can check the graph result inside `../plot/cylon-1t-cdf-1t.pdf`

### Figure 11
This experiment is to see the impact of different eviction policies on Cylon latency in redis. **You must reboot/restart the VM between different eviction policies**.
* Run this script once per policy with a different RUN_TAG. 
    ```sh
    ENABLE_PRELOAD=1 RUN_TAG=fifo  ./run-figure11.sh
    ENABLE_PRELOAD=1 RUN_TAG=lifo  ./run-figure11.sh
    ENABLE_PRELOAD=1 RUN_TAG=clock ./run-figure11.sh
    ENABLE_PRELOAD=1 RUN_TAG=s3fifo ./run-figure11.sh
    ```
* After that you can run 
    ```sh
    gnuplot plot-figure11.gp
    ```
    Check the graph result in `../plot/redis-eviction-cylon.pdf`

### Figure 12
This experiment is to see the impact of prefetching degree on Cylon.
* To run and generate the plot as Figure 12, you can run:
```bash
ENABLE_PRELOAD=1 RUN_TAG=prefetch ./run-figure12.sh
```
* You can check the graph result in `../plot/redis-prefetch-cylon.pdf`

