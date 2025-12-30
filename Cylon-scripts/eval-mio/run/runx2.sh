#!/bin/bash
#RST_DIR="results"
RST_DIR=$1
mem_node=$2
#numactl -N0  -- ./src/bench -t 1 -r 0 -i 10 -I 8 -T 0 > $RST_DIR/N0m0_1.txt
#exit
threads_small=(1 2 4 8 )
threads_large=(1 2 4 8 )
#bsize=( 32768 16384 131072 65536 )
bsize=( 8192 )
strides=( 256 512 1024 4096 )
iter=1

# prefetch=( 1 2 4 8 64 )

mkdir -p $RST_DIR

function run_mio()
{
    nthreads=$1
    ws=$2
    stride_size=$3
    israndom=$4
    prefetch=$5

    size_per_threads=$(( $ws / $nthreads ))

    SECONDS=0
    output="$RST_DIR/N0m${mem_node}_t${nthreads}_b${ws}_s${stride_size}_p${prefetch}${israndom}.txt"
    cmd="numactl -N0 -- ../src/bench_${stride_size} -t $nthreads -r ${mem_node} -i $iter -I 8 -T 0 -m $size_per_threads $israndom"
    echo "$cmd > $output, $size_per_threads"
    $cmd > $output
    echo "Threads: $th, Bsize: $bs, stide: $stride_size, $israndom, Time: $SECONDS"
}

for pd in 1 2 4 8 64; do
    cxl read-labels mem0 -s 5 -O $pd > /dev/null 2>&1

    for ws in 8192; do
        for thread in 1; do
            # rand
            run_mio $thread $ws "64" -R $pd
            
            # # seq
            run_mio $thread $ws "64" "" $pd

            # # #stride
            for ss in "${strides[@]}"; do
                run_mio $thread $ws $ss "" $pd
            done
        done    
    done
done

# for bs in "${bsize[@]}"
# do
#     # Use fewer threads for larger block sizes (131072 and 65536)
#     if [[ $bs -eq 131072 || $bs -eq 65536 ]]; then
#         threads=("${threads_large[@]}")
#     else
#         threads=("${threads_small[@]}")
#     fi
    
#     for th in "${threads[@]}"
#     do
#         SECONDS=0
#         output="$RST_DIR/N0m${mem_node}_t${th}_b${bs}.txt"
#         cmd="numactl -N0 -- ../src/bench -t $th -r ${mem_node} -i $iter -I 8 -T 0 -m $bs -s"
#         echo "$cmd > $output"
#         $cmd > $output
#         echo "Threads: $th, Bsize: $bs, Time: $SECONDS"
#     done
# done
exit

#for (( i=0; i < ${#threads[@]}; i++ ))
#do
#	th=${threads[$i]}
#	bs=${bsize[$i]}
#	it=${iter[$i]}
#	SECONDS=0
#	numactl -N0 -- ../src/bench -t $th -r ${mem_node} -i $it -I 8 -T 0 -m $bs > $RST_DIR/N0m${mem_node}_$th.txt
#	echo $SECONDS
#done
#exit

#for t in 1 2
#do
#	numactl -N0  -- ../src/bench -t $t -r 0 -i 5 -I 8 -T 0 > $RST_DIR/N0m0_$t.txt
#done

#for t in 4 8 16 32
#do
#	numactl -N0  -- ../src/bench -t $t -r 0 -i 3 -I 8 -T 0 > $RST_DIR/N0m0_$t.txt
#done

#for t in 32
#do
#	numactl -N0  -- ../src/bench -t $t -r 0 -i 2 -I 8 -T 0 > $RST_DIR/N0m0_$t.txt
#done
