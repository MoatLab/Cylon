## Intel MLC (Figure 2, 4)

### Figure 2
* Since timestamps are disabled, you may see end-to-end latency only.
    ```sh
    bash figure2.sh
    ```

### Figure 4
* This experiment measures Cylon's bandwidth under different WSS and prefetching (Next-N) degree.
* The plot in the paper compares Cylon (prefetching degree 8) and CMM-H
* Raw data is avaiable at `submission/figure4/script/plot.plot`.

    ```sh
    # Test run
    bash figure4-test.sh

    # Figure 4
    bash figure4.sh
    ```