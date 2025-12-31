#!/usr/bin/env bash
set -euo pipefail

# You must reboot/restart the VM between different eviction policies.
# Run this script once per policy with a different RUN_TAG.
#
# Example:
#   ENABLE_PRELOAD=1 RUN_TAG=fifo  ./run-figure11.sh
#   ENABLE_PRELOAD=1 RUN_TAG=lifo  ./run-figure11.sh
#   ENABLE_PRELOAD=1 RUN_TAG=clock ./run-figure11.sh
#   ENABLE_PRELOAD=1 RUN_TAG=s3fifo ./run-figure11.sh

DIST=${DIST:-zipfian}
KV=${KV:-1kb}
THREADS=1

# Only these two WSS points
SIZES=(1000000 6000000)

RUN_TAG=${RUN_TAG:-}
if [[ -z "$RUN_TAG" ]]; then
  echo "[ERROR] RUN_TAG is required (e.g., fifo/lifo/clock/s3fifo)." >&2
  echo "        Example: ENABLE_PRELOAD=1 RUN_TAG=fifo ./run-figure11.sh" >&2
  exit 1
fi

# Use preload by default for Redis (override if needed)
export ENABLE_PRELOAD=${ENABLE_PRELOAD:-1}

# Where we collect stable outputs for plotting later
OUT_BASE="../dat/figure11/${RUN_TAG}"
mkdir -p "$OUT_BASE"

for n in "${SIZES[@]}"; do
  export THREAD_COUNTS_STR="${THREADS}"
  export RECORD_COUNT="$n"
  export OPERATION_COUNT="$n"

  # Make each run unique but still human-readable
  export RUN_DIR="figure11-${RUN_TAG}-${n}"
  export BENCH_SCRIPT="./benchmark.sh"

  echo "========================================"
  echo "[FIG11] policy=${RUN_TAG} n=${n} threads=${THREADS} dist=${DIST} kv=${KV}"
  echo "        RUN_DIR=${RUN_DIR} ENABLE_PRELOAD=${ENABLE_PRELOAD}"
  echo "========================================"

  bash ./run_process.sh

  # Expected output of run_process.sh (adjust here if your naming differs)
  SRC_DAT="../dat/${RUN_DIR}/${DIST}/${KV}/cmmh-${THREADS}t-off-read.dat"
  if [[ ! -f "$SRC_DAT" ]]; then
    echo "[ERROR] Expected dat not found: $SRC_DAT" >&2
    echo "        Your run_process.sh naming differs. Fix SRC_DAT in run-figure11.sh." >&2
    exit 1
  fi

  OUT_DAT="${OUT_BASE}/${RUN_TAG}-${n}.dat"
  cp -f "$SRC_DAT" "$OUT_DAT"
  echo "[OK] Saved: $OUT_DAT"

done

echo "[DONE] Figure 11 data prepared under: $OUT_BASE"