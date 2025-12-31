## Mio (Figure 3, 6, 9, 10)

Since MIO use devdax, first you need to expose Cylon as devdax device by running
```sh
daxctl reconfigure-device --mode=devdax --force dax0.0
```

### Figure 3
* This experiment is comparing Cylon vs QEMU access latency using MIO. The provided script will run, process, and plot the result for you. You can run it by using `run-figure3.sh` and check the plot inside `../plot/.`.
    ```sh
    cd run
    bash run-figure3.sh
    ```

### Figure 6
* This experiment is comparing Cylon vs CMM-H latency distribution using MIO. The provided script will run, process, and plot the result for you. You can run it by using `run-figure6.sh` and check the plot inside `../plot/.`.
    ```sh
    cd run
    bash run-figure6.sh
    ```