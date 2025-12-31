#!/usr/bin/env bash
set -euo pipefail

# Figure 12: Prefetch degree impact on Redis latency CDF
# Usage:
#   RUN_TAG=fig12 THREADS=1 KV=1kb DIST=zipfian ./run-figure12.sh
#
# Requires:
#   - ./run_process.sh (your pipeline that runs + preprocesses + raw->dat)
#   - ./benchmark.sh
#   - cxl tool available if you want to actually change prefetch degree

DIST=${DIST:-zipfian}
KV=${KV:-1kb}
THREADS=${THREADS:-1}

# 2 WSS points (your request)
SIZES=(1000000 6000000)

# Prefetch degrees
PDS=(0 1 2 4 8)

RUN_TAG=${RUN_TAG:-S3FIFO-prefetch}
DATDIR="../dat/S3FIFO-prefetch"
PLOTDIR="../plot"
mkdir -p "$DATDIR" "$PLOTDIR"

# --- CXL helpers ---
set_prefetch() {
  local pd="$1"
  if command -v cxl >/dev/null 2>&1; then
    # Set next-n prefetch degree
    cxl read-labels mem0 -s 5 -O "$pd" >/dev/null 2>&1 || true
    # Print cache info (optional)
    cxl read-labels mem0 -s 1 >/dev/null 2>&1 || true
  else
    echo "[WARN] cxl tool not found; skipping prefetch-degree setting"
  fi
}

cleanup() {
  # Reset prefetch to 0
  if command -v cxl >/dev/null 2>&1; then
    cxl read-labels mem0 -s 5 -O 0 >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# --- Run loop ---
for pd in "${PDS[@]}"; do
  echo "========================================"
  echo "[PREFETCH] degree=$pd"
  echo "========================================"
  set_prefetch "$pd"

  for n in "${SIZES[@]}"; do
    # Configure your existing pipeline (same pattern as run-figure7.sh)
    export ENABLE_PRELOAD=${ENABLE_PRELOAD:-0}
    export THREAD_COUNTS_STR="${THREADS}"
    export RECORD_COUNT="$n"
    export OPERATION_COUNT="$n"
    export RUN_DIR="${RUN_TAG}-${n}-p${pd}"
    export BENCH_SCRIPT="./benchmark.sh"

    echo "------------------------------"
    echo "Running Redis: n=$n pd=$pd RUN_DIR=$RUN_DIR"
    echo "------------------------------"
    bash ./run_process.sh

    # run_process.sh produces:
    #   ../dat/<RUN_DIR>/<DIST>/<KV>/cmmh-<THREADS>t-off-read.dat
    SRC_DAT="../dat/${RUN_DIR}/${DIST}/${KV}/cmmh-${THREADS}t-off-read.dat"
    if [[ ! -f "$SRC_DAT" ]]; then
      echo "[ERROR] Expected dat not found: $SRC_DAT" >&2
      echo "        Your run_process.sh naming differs. Fix SRC_DAT path." >&2
      exit 1
    fi

    # Stable naming for plotting:
    #   ../dat/S3FIFO-prefetch/<threads>-<dist>-<n>-<pd>_run.log.dat
    OUT_DAT="${DATDIR}/${THREADS}-${DIST}-${n}-${pd}_run.log.dat"
    cp -f "$SRC_DAT" "$OUT_DAT"
    echo "[OK] Wrote: $OUT_DAT"
  done
done

# --- Plot (embedded gnuplot, no extra files) ---
if ! command -v gnuplot >/dev/null 2>&1; then
  echo "[WARN] gnuplot not found; skipping plot" >&2
  exit 0
fi

OUT_PDF="${PLOTDIR}/redis-prefetch-cylon.pdf"

gnuplot -e "OUT='${OUT_PDF}';DATDIR='${DATDIR}';T=${THREADS};DIST='${DIST}'" \
  plot-figure12.gp

[[ -f "$OUT_PDF" ]] || { echo "[ERROR] Plot not created: $OUT_PDF" >&2; exit 1; }
echo "[OK] Wrote: $OUT_PDF"