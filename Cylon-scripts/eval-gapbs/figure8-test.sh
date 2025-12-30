
TEST=figure8-test
RESULTDIR="dat/$TEST"

mkdir -p $RESULTDIR

GAPBS_DIR=/root/gapbs
GAPBS_GRAPH_DIR=$GAPBS_DIR/benchmark/graphs/

export OMP_NUM_THREADS=8
for g in 26; do
    LD_PRELOAD=/root/pin_binary.so ${GAPBS_DIR}/bc -f ${GAPBS_GRAPH_DIR}/kron-g$g.sg -i4 -n4  2>&1 | tee $RESULTDIR/${g}.result
done

