#!/usr/bin/env bash
set -euo pipefail

# One-command pipeline (prefetching degree):
#   ./run-figure6.sh
# will:
#   1) sweep prefetch degree (0/1/2/4/8) and run MIO workloads:
#        [a] Seq (stride 64)
#        [b] Rand (stride 64, -R)
#        [c] Stride-512
#        [d] Stride-1024
#        [e] Stride-4096
#   2) preprocess raw -> dat (CDF) using ../script/raw2dat.sh
#   3) plot using an external gnuplot script (keep plot separate): set PLOT_GP=/path/to/plot.gp
#
# Defaults are chosen to match your existing plot file:
#   ../dat/S3FIFO_prefetch/N0m1_t1_b8192_s{64,512,1024,4096}_p{0,1,2,4,8}[ -R ].dat
#
# Optional overrides:
#   TARGET=... MEM_NODE=... THREADS=... WS=... ITER=...
#   PD_LIST="0 1 2 4 8" REPEAT=4 REPEAT_RAND=1
#   MIN_NS=... MAX_NS=... PRECISION=...
#   PLOT_GP=/abs/or/relative/path/to/your.gp

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPDIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET="${TARGET:-S3FIFO_prefetch}"
MEM_NODE=1
THREADS=1
WS=8192
ITER=1

PD_LIST=(${PD_LIST:-0 1 2 4 8})
REPEAT="${REPEAT:-4}"             # concatenate 4 runs (avg by sample pooling)
REPEAT_RAND="${REPEAT_RAND:-1}"   # random is noisy; default 1 run

MIN_NS="${MIN_NS:-0.0}"
MAX_NS="${MAX_NS:-1.0}"
PRECISION="${PRECISION:-0.00001}"

if ! command -v numactl >/dev/null 2>&1; then
  echo "[ERROR] numactl not found in PATH" >&2
  exit 1
fi

# Try common locations for your plot file unless PLOT_GP is provided.
# (You said you prefer plot scripts separate — keep it that way.)
if [[ -z "${PLOT_GP:-}" ]]; then
  if [[ -f "${TOPDIR}/run/plot-fig10.gp" ]]; then
    PLOT_GP="${TOPDIR}/run/plot-fig10.gp"
  elif [[ -f "${TOPDIR}/gp/plot.gp" ]]; then
    # fallback if you keep one generic plot.gp
    PLOT_GP="${TOPDIR}/gp/plot.gp"
  fi
fi

RAWDIR="${TOPDIR}/raw/${TARGET}"
mkdir -p "${RAWDIR}" "${TOPDIR}/plot"

set_prefetch() {
  local pd="$1"
  if command -v cxl >/dev/null 2>&1; then
    # Set Next-n prefetching degree
    cxl read-labels mem0 -s 5 -O "$pd" >/dev/null 2>&1 || true
    # Print caching info (optional)
    cxl read-labels mem0 -s 1 >/dev/null 2>&1 || true
  else
    echo "[WARN] cxl tool not found; skipping prefetch setting (pd=$pd)" >&2
  fi
}

cleanup() {
  # Reset prefetch degree to 0 on exit
  if command -v cxl >/dev/null 2>&1; then
    cxl read-labels mem0 -s 5 -O 0 >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

run_mio_one() {
  local pd="$1"
  local stride="$2"      # 64/512/1024/4096
  local rand_flag="$3"   # "" or "-R"
  local reps="$4"

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

  # IMPORTANT: keep names matching your gnuplot script.
  # raw2dat.sh will convert these to .dat with the same basename.
  local out_base="N0m${MEM_NODE}_t${THREADS}_b${WS}_s${stride}_p${pd}${suffix}"

  for ((r=1; r<=reps; r++)); do
    local output="${RAWDIR}/${out_base}_r${r}.txt"

    # argv array (robust)
    local -a cmd=(
      numactl -N0 -- "${bench}"
      -t "${THREADS}"
      -r "${MEM_NODE}"
      -i "${ITER}"
      -I 8
      -T 0
      -m "${size_per_thread}"
    )

    # Add random flag if requested
    if [[ -n "$rand_flag" ]]; then
      cmd+=("$rand_flag")
    fi

    echo "[RUN] pd=${pd} stride=${stride} rand=${rand_flag:-0} rep=${r} -> ${output}"
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

  # Sanity-check a few expected outputs (pd=0 only); full set is large.
  for f in \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s64_p0.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s64_p0-R.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s512_p0.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s1024_p0.dat" \
    "${datdir}/N0m${MEM_NODE}_t${THREADS}_b${WS}_s4096_p0.dat"; do
    if [[ ! -f "$f" ]]; then
      echo "[ERROR] Missing dat file: $f" >&2
      echo "        Check that raw logs exist under: ${RAWDIR}" >&2
      echo "        Also ensure raw2dat.sh understands the output format." >&2
      exit 1
    fi
  done

  echo "[OK] dat files ready under: ${datdir}"
}

plot() {
  if [[ -z "${PLOT_GP:-}" ]]; then
    echo "[SKIP] No PLOT_GP set/found. You said you want plotting separate — that's fine." >&2
    echo "       To plot now: PLOT_GP=/path/to/your.gp ./run-figure6.sh" >&2
    return 0
  fi
  if [[ ! -f "${PLOT_GP}" ]]; then
    echo "[ERROR] plot.gp not found: ${PLOT_GP}" >&2
    exit 1
  fi

  local plot_dir
  plot_dir="$(cd "$(dirname "${PLOT_GP}")" && pwd)"
  local plot_base
  plot_base="$(basename "${PLOT_GP}")"

  echo "[PLOT] gnuplot ${PLOT_GP}"
  ( cd "${plot_dir}" && gnuplot "${plot_base}" )

  echo "[OK] Plot generated (check ../plot/ from plot.gp): ${TOPDIR}/plot/"
}

# ---- One-command flow ----
for pd in "${PD_LIST[@]}"; do
  echo "========================================"
  echo "[PREFETCH] degree=${pd}"
  echo "========================================"
  set_prefetch "$pd"

  # [a] Seq (stride=64)
  run_mio_one "$pd" 64 "" "$REPEAT"

  # [b] Rand (stride=64, -R)
  run_mio_one "$pd" 64 "-R" "$REPEAT_RAND"

  # [c][d][e] Strides
  run_mio_one "$pd" 512 "" "$REPEAT"
  run_mio_one "$pd" 1024 "" "$REPEAT"
  run_mio_one "$pd" 4096 "" "$REPEAT"
done

echo "[OK] raw logs under: ${RAWDIR}"
preprocess
plot