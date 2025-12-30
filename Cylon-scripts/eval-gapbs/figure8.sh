export OMP_NUM_THREADS=8

GAPBS_DIR=/root/gapbs
GAPBS_GRAPH_DIR=$GAPBS_DIR/benchmark/graphs/

for g in 26 27 28;do
    LD_PRELOAD=/root/pin_binary.so ${GAPBS_DIR}/bc -f ${GAPBS_GRAPH_DIR}/kron-g$g.sg -i4 -n4
done

