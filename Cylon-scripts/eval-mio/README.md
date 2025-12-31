## Mio (Figure 3, 6, 9, 10)

Since MIO use devdax, first you need to expose Cylon as devdax device by running
```sh
daxctl reconfigure-device --mode=devdax --force dax0.0
```

### Figure 3
* This experiment is comparing Cylon vs QEMU access latency using MIO. The provided script will run, process, and plot the result for you. You can run it by using `run-figure3.sh` and check the plot inside `../plot/figure3.pdf`.
    ```sh
    cd run
    bash run-figure3.sh
    ```

### Figure 6
* This experiment is comparing Cylon vs CMM-H latency distribution using MIO. The provided script will run, process, and plot the result for you. You can run it by using `run-figure6.sh` and check the plot inside `../plot/mio-cmmh-cylon-t4.pdf`.
    ```sh
    cd run
    bash run-figure6.sh
    ```

### Figure 9
This experiment is to see the impact of different eviction policies on Cylon latency using MIO. **You must reboot/restart the VM between different eviction policies**.
* Run this script once per policy with a different RUN_TAG. 
    ```sh
    RUN_TAG=FIFO-NAND2  ./run-figure9.sh
    RUN_TAG=LIFO-NAND2  ./run-figure9.sh
    RUN_TAG=CLOCK-NAND2 ./run-figure9.sh
    RUN_TAG=S3FIFO-NAND2 ./run-figure9.sh
    ```
* After that you can run 
    ```sh
    gnuplot plot-fig9.gp
    ```
    Check the graph result in `../plot/mio-eviction.pdf`

### Figure 10
* This experiment is to see the impact of prefetching degree on Cylon latency using MIO. The script will run, process, and plot the result for you. To get the result, you just need to run this and check the plot inside `../plot/prefetching-fifo.pdf`:
    ```sh
    cd run
    bash run-figure10.sh
    ```