#!/usr/bin/env bash
set -euo pipefail

# Figure 9: MIO eviction policy impact on latency CDF
# You MUST reboot/restart VM to change eviction policy.
# Run once per policy with RUN_TAG matching your plot directories:
#   RUN_TAG=FIFO-NAND2  ./run-figure9.sh
#   RUN_TAG=LIFO-NAND2  ./run-figure9.sh
#   RUN_TAG=CLOCK-NAND2 ./run-figure9.sh
#   RUN_TAG=S3FIFO-NAND2 ./run-figure9.sh
#
# Then later plot with gnuplot plot-figure9.gp.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPDIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUN_TAG="${RUN_TAG:-}"
if [[ -z "$RUN_TAG" ]]; then
  echo "[ERROR] RUN_TAG is required (e.g., FIFO-NAND2 / LIFO-NAND2 / CLOCK-NAND2 / S3FIFO-NAND2)" >&2
  exit 1
fi

MEM_NODE=1
THREADS=1
WS=8192
ITER=1

REPEAT="${REPEAT:-4}"             
REPEAT_RAND="${REPEAT_RAND:-1}" 

MIN_NS="${MIN_NS:-0.0}"
MAX_NS="${MAX_NS:-1.0}"
PRECISION="${PRECISION:-0.00001}"

if ! command -v numactl >/dev/null 2>&1; then
  echo "[ERROR] numactl not found in PATH" >&2
  exit 1
fi

TARGET="$RUN_TAG"
RAWDIR="${TOPDIR}/raw/${TARGET}"
mkdir -p "${RAWDIR}"

run_mio_one() {
  local stride="$1"      # 64/512/1024/4096
  local rand_flag="$2"   # "" or "-R"
  local reps="$3"

  local size_per_thread=$(( $WS / $THREADS ))
  local bench="${TOPDIR}/src/bench_${stride}"
  if [[ ! -x "${bench}" ]]; then
    echo "[ERROR] bench not found/executable: ${bench}" >&2
    exit 1
  fi

  local suffix=""
  if [[ "$rand_flag" == "-R" ]]; then
    suffix="-R"
  fi

  local out_base="N0m${MEM_NODE}_t${THREADS}_b${WS}_s${stride}${suffix}"

  for ((r=1; r<=reps; r++)); do
    local output="${RAWDIR}/${out_base}_r${r}.txt"

    local -a cmd=(
      numactl -N0 -- "${bench}"
      -t "${THREADS}"
      -r "${MEM_NODE}"
      -i "${ITER}"
      -I 8
      -T 0
      -m "${size_per_thread}"
    )
    [[ -n "$rand_flag" ]] && cmd+=("$rand_flag")

    echo "[RUN] tag=${RUN_TAG} stride=${stride} rand=${rand_flag:-0} rep=${r} -> ${output}"
    "${cmd[@]}" > "${output}"
  done
}

preprocess() {
  local raw2dat="${TOPDIR}/script/raw2dat.sh"
  if [[ ! -x "${raw2dat}" ]]; then
    echo "[ERROR] Cannot execute: ${raw2dat}" >&2
    exit 1
  fi

  echo "[PROC] raw -> dat: TARGET=${TARGET} MIN=${MIN_NS} MAX=${MAX_NS} PRECISION=${PRECISION}"
  "${raw2dat}" lat-cdf "${TARGET}" "${MIN_NS}" "${MAX_NS}" "${PRECISION}"

  local datdir="${TOPDIR}/dat/${TARGET}"

  for f in \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s64.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s64-R.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s512.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s1024.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s4096.dat"; do
    if [[ ! -f "$f" ]]; then
      echo "[ERROR] Missing dat file: $f" >&2
      echo "        Check raw logs under: ${RAWDIR}" >&2
      exit 1
    fi
  done

  echo "[OK] dat files ready under: ${datdir}"
}

# ---- Run workloads ----
echo "========================================"
echo "[FIG9] RUN_TAG=${RUN_TAG}"
echo "========================================"

# [a] Seq
run_mio_one 64 "" "$REPEAT"

# [b] Rand
run_mio_one 64 "-R" "$REPEAT_RAND"

# [c][d][e] Strides
run_mio_one 512 "" "$REPEAT"
run_mio_one 1024 "" "$REPEAT"
run_mio_one 4096 "" "$REPEAT"

echo "[OK] raw logs under: ${RAWDIR}"
preprocess
echo "[DONE] Now plot later with your gnuplot plot-figure9.gp"