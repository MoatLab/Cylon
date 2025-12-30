TEST=figure2
RESULTDIR="dat/$TEST"
MLC=/root/mlc/mlc

mkdir -p $RESULTDIR

output=$RESULTDIR/result
echo > $output

./mlc --latency_matrix >> $output
./mlc --latency_matrix >> $output
./mlc --latency_matrix >> $output