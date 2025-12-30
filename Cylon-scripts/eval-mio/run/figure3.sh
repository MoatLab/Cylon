#!/bin/bash
RST_DIR="result/raw"
TEST="figure3"

mem_node=1
iter=4

mkdir -p $RST_DIR

function run_mio()
{
    nthreads=$1
    ws=$2
    stride_size=$3
    israndom=$4

    size_per_threads=$(( $ws / $nthreads ))

    SECONDS=0
    output="$RST_DIR/N0m${mem_node}_t${nthreads}_b${ws}_s${stride_size}${israndom}.txt"
    cmd="numactl -N0 -- ../src/bench_${stride_size} -t $nthreads -r ${mem_node} -i $iter -I 8 -T 0 -m $size_per_threads $israndom"
    echo "$cmd > $output, $size_per_thread"
    $cmd > $output
    echo "Threads: $th, Bsize: $bs, stide: $stride_size, $israndom, Time: $SECONDS"
}

for ws in 8192; do
    for thread in 8; do
        # seq
        run_mio $thread $ws "64" ""
    done    
done

