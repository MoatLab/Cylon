#!/usr/bin/env bash
set -euo pipefail

# Minimal MLC pipeline:
#   1) Run: ./mlc --bandwidth_matrix -b<bs> and store result/<tag>/<bs>.result
#   2) Parse: one Cylon bandwidth per bs (from node 1)
#   3) Plot: inline table with your fixed WSS points + your provided CMM-H numbers
#
# Usage:
#   ./run-figure.sh <RUN_TAG>

TAG=${1:-}
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <RUN_TAG>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
cd "$SCRIPT_DIR"

RESULTDIR="result/$TAG"
mkdir -p "$RESULTDIR" plot

BS_LIST=(26m 52m 104m 208m 416m 832m 1664m)
WSS_LIST=(0.04 0.08 0.17 0.33 0.67 1.33 2.67)

CMMH_LIST=(22345.5 22189.1 22076.8 21481.8 2630.3 1112.6 835.2)

parse_bw_node1() {
  awk '/^[[:space:]]*0[[:space:]]+/ { print $3; exit }' "$1"
}

extract_cylon_bw() {
  local f="$1"
  local bw=""

  bw=$(parse_bw_node1 "$f" || true)

  # If everything fails, return NaN (but don't crash)
  [[ -n "$bw" ]] && echo "$bw" || echo "NaN"
}

# ---- 1) Run MLC ----
for bs in "${BS_LIST[@]}"; do
  echo "[RUN] bs=$bs"
  $MLC --bandwidth_matrix -b"$bs" -t30 2>&1 | tee "$RESULTDIR/$bs.result" >/dev/null
 done

# ---- 2) Build inline data table ----
# columns: WSS  Cylon  CMMH
DATA_LINES=$'# WSS Cylon CMMH\n'
for i in "${!BS_LIST[@]}"; do
  bs="${BS_LIST[$i]}"
  wss="${WSS_LIST[$i]}"
  cmm="${CMMH_LIST[$i]}"

  cylon_bw=$(extract_cylon_bw "$RESULTDIR/$bs.result")
  DATA_LINES+="$wss $cylon_bw $cmm"$'\n'
done

# Write table to a temp file
TABLE_FILE="$RESULTDIR/mlc_table.txt"
printf "%s" "$DATA_LINES" > "$TABLE_FILE"

# ---- 3) Plot ----
OUT_PDF="plot/cylon-cmmh-mlc.pdf"
if command -v gnuplot >/dev/null 2>&1; then
  GP_LOG="$RESULTDIR/gnuplot.log"
  gnuplot -e "OUT='${OUT_PDF}';TABLE='${TABLE_FILE}'" \
  plot.gp
  [[ -f "$OUT_PDF" ]] || { echo "[ERROR] Plot not created: $OUT_PDF (see $GP_LOG)" >&2; exit 1; }
  echo "[OK] Plot: $OUT_PDF"
else
  echo "[WARN] gnuplot not found; skipping plot" >&2
fi
