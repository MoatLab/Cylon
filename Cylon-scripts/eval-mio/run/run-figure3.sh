#!/usr/bin/env bash
set -euo pipefail

# One-command pipeline:
#   ./runx.sh
# will:
#   1) run ONLY (t=4, stride=64) at b=1638 and b=6554
#   2) preprocess raw -> dat (CDF)
#   3) plot using plot.gp
#
# Optional overrides:
#   TARGET=...   MEM_NODE=...   PLOT_GP=...   MIN_NS=... MAX_NS=... PRECISION=...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPDIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET="${TARGET:-linear}"
MEM_NODE=1
MIN_NS="${MIN_NS:-0.0}"
MAX_NS="${MAX_NS:-1.0}"
PRECISION="${PRECISION:-0.00001}"

# Try common locations for your plot file unless PLOT_GP is provided.
if [[ -z "${PLOT_GP:-}" ]]; then
  if [[ -f "${TOPDIR}/run/plot-fig3.gp" ]]; then
    PLOT_GP="${TOPDIR}/run/plot-fig3.gp"
  else
    echo "[ERROR] Cannot find plot.gp. Set PLOT_GP=/path/to/plot.gp" >&2
    echo "        Tried: ${TOPDIR}/gp/plot.gp, ${TOPDIR}/eval-mio/plot.gp, ${TOPDIR}/plot.gp" >&2
    exit 1
  fi
fi

if ! command -v numactl >/dev/null 2>&1; then
  echo "[ERROR] numactl not found in PATH" >&2
  exit 1
fi

RAWDIR="${TOPDIR}/raw/${TARGET}"
mkdir -p "${RAWDIR}" "${TOPDIR}/plot"

THREADS=8
STRIDE=64
ITER=4

run_mio() {
  local ws="$1"
  local size_per_thread=$(( ws / THREADS ))

  local bench="${TOPDIR}/src/bench_${STRIDE}"
  if [[ ! -x "${bench}" ]]; then
    echo "[ERROR] bench not found/executable: ${bench}" >&2
    exit 1
  fi

  local output="${RAWDIR}/N0m${MEM_NODE}_t${THREADS}_b${ws}_s${STRIDE}.txt"

  # argv array (robust)
  local -a cmd=(
    numactl -N0 -- "${bench}"
    -t "${THREADS}"
    -r 1
    -i 1
    -I 8
    -T 0
    -m "${size_per_thread}"
  )

  echo "[RUN] ws=${ws} threads=${THREADS} stride=${STRIDE} -> ${output}"
  "${cmd[@]}" > "${output}"
}

preprocess() {
  local raw2dat="${TOPDIR}/script/raw2dat.sh"
  if [[ ! -x "${raw2dat}" ]]; then
    echo "[ERROR] Cannot execute: ${raw2dat}" >&2
    exit 1
  fi

  echo "[PROC] raw -> dat: TARGET=${TARGET} MIN=${MIN_NS} MAX=${MAX_NS} PRECISION=${PRECISION}"
  "${raw2dat}" lat-cdf "${TARGET}" "${MIN_NS}" "${MAX_NS}" "${PRECISION}"

  # Quick sanity: ensure expected .dat exist
  local datdir="${TOPDIR}/dat/${TARGET}"
  for ws in 8192; do
    local f="${datdir}/N0m${MEM_NODE}_t${THREADS}_b${ws}_s${STRIDE}.dat"
    if [[ ! -f "${f}" ]]; then
      echo "[ERROR] Missing dat file: ${f}" >&2
      echo "        Check that raw logs exist under: ${RAWDIR}" >&2
      exit 1
    fi
  done
  echo "[OK] dat files ready under: ${datdir}" 
}

plot() {
  if [[ ! -f "${PLOT_GP}" ]]; then
    echo "[ERROR] plot-fig3.gp not found: ${PLOT_GP}" >&2
    exit 1
  fi

  local plot_dir
  plot_dir="$(cd "$(dirname "${PLOT_GP}")" && pwd)"
  local plot_base
  plot_base="$(basename "${PLOT_GP}")"

  echo "[PLOT] gnuplot ${PLOT_GP}"
  ( cd "${plot_dir}" && gnuplot "${plot_base}" )

  echo "[OK] Plot generated (check ../plot/ from plot-fig3.gp): ${TOPDIR}/plot/"
}

# ---- One-command flow ----
run_mio 8192

echo "[OK] raw logs under: ${RAWDIR}"
preprocess
plot