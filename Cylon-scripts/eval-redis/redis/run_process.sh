#!/usr/bin/env bash
set -euo pipefail

# Pipeline: run benchmark -> preprocess -> raw2dat
#
# Expected files in the *current directory* (or override via env vars below):
#   - benchmark.sh (BENCH_SCRIPT)
#   - run-fix-simple.sh
#   - redis2.conf
#   - preprocess.sh (PREPROCESS_SCRIPT)
#   - raw2dat.sh (RAW2DAT_SCRIPT)
#
# Your existing preprocess.sh convention (based on preprocess-all.sh) seems to be:
#   preprocess.sh <input_run_log> <output_dir> <log_prefix>
# where output_dir is relative to ../raw and ../dat.

BENCH_SCRIPT="${BENCH_SCRIPT:-./benchmark.sh}"
PREPROCESS_SCRIPT="${PREPROCESS_SCRIPT:-./../script/preprocess.sh}"
RAW2DAT_SCRIPT="${RAW2DAT_SCRIPT:-./../script/raw2dat.sh}"

TYPE="${TYPE:-lat-cdf}"
MIN="${MIN:-0.0}"
MAX="${MAX:-1.0}"
PRECISION="${PRECISION:-0.00001}"

RUN_BENCH=1
FORCE=0

usage() {
  cat <<USAGE
Usage: $0 [--no-run] [--run-dir DIR] [--force]

  --no-run        Skip running the benchmark; only preprocess + raw2dat.
  --run-dir DIR   Directory containing benchmark results (default: extracted from benchmark script).
  --force         Re-run preprocess/raw2dat even if outputs exist.

Env overrides:
  BENCH_SCRIPT, PREPROCESS_SCRIPT, RAW2DAT_SCRIPT, TYPE, MIN, MAX, PRECISION
USAGE
}

#RUN_DIR=""
RUN_DIR="${RUN_DIR:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-run) RUN_BENCH=0; shift ;;
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if [[ -z "$RUN_DIR" ]]; then
  if [[ -f "$BENCH_SCRIPT" ]]; then
    # Extract RUN_DIR="..." from benchmark script.
    RUN_DIR=$(awk -F= '/^RUN_DIR=/{gsub(/"/,"",$2); print $2; exit}' "$BENCH_SCRIPT" || true)
  fi
fi

if [[ -z "$RUN_DIR" ]]; then
  echo "ERROR: Could not determine RUN_DIR. Pass --run-dir DIR." >&2
  exit 1
fi

need_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Missing required file: $f" >&2
    exit 1
  fi
}

need_file "$PREPROCESS_SCRIPT"
need_file "$RAW2DAT_SCRIPT"

if [[ $RUN_BENCH -eq 1 ]]; then
  need_file "$BENCH_SCRIPT"
  need_file "./run-fix-simple.sh"
  need_file "./redis2.conf"

  echo "[1/3] Running benchmark: $BENCH_SCRIPT"
  # benchmark-2.sh pauses for ENTER. Feed a newline so it runs unattended.
  printf '\n' | bash "$BENCH_SCRIPT"
fi

if [[ ! -d "$RUN_DIR" ]]; then
  echo "ERROR: RUN_DIR does not exist: $RUN_DIR" >&2
  exit 1
fi

echo "[2/3] Preprocessing YCSB raw logs under: $RUN_DIR"

# Collect unique (out_dist, kv) pairs for the raw2dat stage.
# Key format: out_dist|||kv
declare -A combos=()

mapfile -t RUN_LOGS < <(find "$RUN_DIR" -type f -name "*_run.log" | sort)

if [[ ${#RUN_LOGS[@]} -eq 0 ]]; then
  echo "ERROR: No *_run.log files found under $RUN_DIR" >&2
  exit 1
fi

for log_path in "${RUN_LOGS[@]}"; do
  rel="${log_path#"$RUN_DIR/"}"
  # Expected pattern from benchmark.sh:
  #   benchmark-hugepage.sh:
  #     <distribution>/<memory>-<kv>/<thread>t/<RUN-...>/<...>_run.log
  dist="${rel%%/*}"
  rest="${rel#*/}"
  memkv="${rest%%/*}"
  rest="${rest#*/}"
  thread_dir="${rest%%/*}"   # e.g., 4t
  rest="${rest#*/}"
  next_dir="${rest%%/*}"
  thp="off"
  if [[ "$next_dir" == thp-* ]]; then
    thp="${next_dir#thp-}"
  fi

  mem="${memkv%%-*}"
  kv="${memkv#*-}"
  if [[ "$kv" == "$memkv" ]]; then
    kv="$memkv"
  fi

  

  # Output tag: make it deterministic, so raw2dat can find it later.
  out_dist="${RUN_DIR}/${dist}"
  out_dir="${out_dist}/${kv}"
  log_prefix="${mem}-${thread_dir}-${thp}"

  # Optional skip if raw already exists (depends on your preprocess.sh behavior).
  if [[ $FORCE -eq 0 ]]; then
    # If preprocess.sh produces ../raw/<out_dir>/<log_prefix>.log (common pattern), skip when present.
    if compgen -G "../raw/${out_dir}/${log_prefix}*.log" > /dev/null; then
      echo "  skip (already preprocessed): $log_path"
      combos["$out_dist|||$kv"]=1
      continue
    fi
  fi

  echo "  preprocess: $log_path"
  bash "$PREPROCESS_SCRIPT" "$log_path" "$out_dir" "$log_prefix"
  combos["$out_dist|||$kv"]=1
done

echo "[3/3] Converting raw -> dat (TYPE=$TYPE, MIN=$MIN, MAX=$MAX, PRECISION=$PRECISION)"

for key in "${!combos[@]}"; do
  out_dist="${key%%|||*}"
  kv="${key#*|||}"

  if [[ ! -d "../raw/${out_dist}/${kv}" ]]; then
    echo "  warning: missing raw dir, skipping: ../raw/${out_dist}/${kv}" >&2
    continue
  fi

  if [[ $FORCE -eq 0 ]]; then
    # If dat already exists, skip.
    if compgen -G "../dat/${out_dist}/${kv}/*.dat" > /dev/null; then
      echo "  skip (dat exists): ${out_dist}/${kv}"
      continue
    fi
  fi

  echo "  raw2dat: ${out_dist}/${kv}"
  bash "$RAW2DAT_SCRIPT" "$TYPE" "${out_dist}/${kv}" "$MIN" "$MAX" "$PRECISION"
done

echo "Done."
echo "  Raw logs: ../raw/"
echo "  Dat files: ../dat/"

