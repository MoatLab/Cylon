#!/usr/bin/env bash
set -euo pipefail

# Run 1-thread experiments for 1M, 3M, 6M records/ops, preprocess -> dat, then plot a CDF PDF.
#
# Assumes these scripts exist in the current directory:
#   ./benchmark-hugepage-v2.sh
#   ./run_and_process-v2.sh
#   ./run-fix-simple.sh
#   ./redis2.conf
#   ./preprocess.sh
#   ./raw2dat.sh
#
# Optional: set YCSB_BIN=/path/to/ycsb

DIST=${DIST:-zipfian}
KV=${KV:-1kb}

# Your CMM-H *existing* dat roots (edit to match your real paths).
# If you don't want to plot CMM-H, set them to "" and edit the gnuplot accordingly.
CMMH_SMALL_DAT=${CMMH_SMALL_DAT:-"../dat/cmmh-jemalloc-10m/${KV}/cmmh-1t-off-read.dat"}
CMMH_MED_DAT=${CMMH_MED_DAT:-"../dat/cmmh-jemalloc-30m/${KV}/cmmh-1t-off-read.dat"}
CMMH_LARGE_DAT=${CMMH_LARGE_DAT:-"../dat/cmmh-jemalloc-60m/${KV}/cmmh-1t-off-read.dat"}

# Where to store your Cylon results (three separate runs so recordcount/opcount can change).
RUN_TAG=${RUN_TAG:-cylon-1t}

SIZES=(10000 30000 60000)

for n in "${SIZES[@]}"; do
  export ENABLE_TCMALLOC=${ENABLE_TCMALLOC:-0}
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

# Build the expected Cylon dat paths (after run_and_process-v2 uses out_dist=RUN_DIR/dist).
SMALL_DAT="../dat/${RUN_TAG}-10000/${DIST}/${KV}/cmmh-1t-off-read.dat"
MED_DAT="../dat/${RUN_TAG}-30000/${DIST}/${KV}/cmmh-1t-off-read.dat"
LARGE_DAT="../dat/${RUN_TAG}-60000/${DIST}/${KV}/cmmh-1t-off-read.dat"

mkdir -p ../plot

gnuplot -e "SMALL_DAT='${SMALL_DAT}';MED_DAT='${MED_DAT}';LARGE_DAT='${LARGE_DAT}';CMMH_SMALL_DAT='${CMMH_SMALL_DAT}';CMMH_MED_DAT='${CMMH_MED_DAT}';CMMH_LARGE_DAT='${CMMH_LARGE_DAT}';OUT_PDF='../plot/${RUN_TAG}-cdf-1t.pdf'" \
  plot.gp

echo "Wrote: ../plot/${RUN_TAG}-cdf-1t.pdf"

