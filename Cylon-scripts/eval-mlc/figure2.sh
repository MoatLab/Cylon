TEST=figure2
RESULTDIR="dat/$TEST"
MLC=/root/mlc/mlc

mkdir -p $RESULTDIR

output=$RESULTDIR/result
echo > $output

$MLC --latency_matrix >> $output
$MLC --latency_matrix >> $output
$MLC --latency_matrix >> $output