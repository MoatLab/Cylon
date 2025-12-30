#!/usr/bin/env bash
set -euo pipefail

DIST=${DIST:-zipfian}
KV=${KV:-1kb}

CMMH_SMALL_DAT=${CMMH_SMALL_DAT:-"../dat/cmmh-jemalloc-10m/${KV}/cmmh-1t-off-read.dat"}
CMMH_MED_DAT=${CMMH_MED_DAT:-"../dat/cmmh-jemalloc-30m/${KV}/cmmh-1t-off-read.dat"}
CMMH_LARGE_DAT=${CMMH_LARGE_DAT:-"../dat/cmmh-jemalloc-60m/${KV}/cmmh-1t-off-read.dat"}

RUN_TAG=${RUN_TAG:-cylon-1t}

SIZES=(1000000 3000000 6000000)

for n in "${SIZES[@]}"; do
  export ENABLE_PRELOAD=${ENABLE_PRELOAD:-0}
  export THREAD_COUNTS_STR="1"
  export RECORD_COUNT="$n"
  export OPERATION_COUNT="$n"
  export RUN_DIR="${RUN_TAG}-${n}"
  export BENCH_SCRIPT="./benchmark.sh"
 
  echo "=============================="
  echo $RUN_DIR
  echo "Running: RUN_DIR=$RUN_DIR (records/ops=$n, 1 thread)"
  echo "=============================="
  bash ./run_process.sh
done

SMALL_DAT="../dat/${RUN_TAG}-1000000/${DIST}/${KV}/cmmh-1t-off-read.dat"
MED_DAT="../dat/${RUN_TAG}-3000000/${DIST}/${KV}/cmmh-1t-off-read.dat"
LARGE_DAT="../dat/${RUN_TAG}-6000000/${DIST}/${KV}/cmmh-1t-off-read.dat"

mkdir -p ../plot

gnuplot -e "SMALL_DAT='${SMALL_DAT}';MED_DAT='${MED_DAT}';LARGE_DAT='${LARGE_DAT}';CMMH_SMALL_DAT='${CMMH_SMALL_DAT}';CMMH_MED_DAT='${CMMH_MED_DAT}';CMMH_LARGE_DAT='${CMMH_LARGE_DAT}';OUT_PDF='../plot/${RUN_TAG}-cdf-1t.pdf'" \
  plot.gp

echo "Wrote: ../plot/${RUN_TAG}-cdf-1t.pdf"

