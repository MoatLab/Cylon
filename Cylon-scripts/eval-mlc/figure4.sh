TEST=figure4
RESULTDIR="dat/$TEST"
MLC=/root/mlc/mlc

for pd in 0 1 2 4 8; do
    # Set Next-n prefeching degree to 0
    cxl read-labels mem0 -s 5 -O $pd > /dev/null 2>&1

    # Print Cylon caching info
    cxl read-labels mem0 -s 1 > /dev/null 2>&1

    # Varying WSS (working set size)
    for bs in 26m 52m 104m 208m 416m 832m 1664m; do
        # Run MLC
        $MLC --bandwidth_matrix -b$bs -t30 2>&1 | tee $RESULTDIR/${bs}_p${pd}.result

        # Print Cylon caching info
        cxl read-labels mem0 -s 1 > /dev/null 2>&1
    done
done

# Reset Next-n prefeching degree to 0
cxl read-labels mem0 -s 5 -O 0 > /dev/null 2>&1
    