#!/usr/bin/env bash
set -euo pipefail

# Hugepage-only YCSB Redis benchmark automation.
# - No THP toggles, no thp-* directory level.
# - Loads once per (memory_mode, distribution, kv) then runs all thread counts.

# --------- Top-level knobs (override via env) ---------
NODE_LOCAL=${NODE_LOCAL:-0}
NODE_CMMH=${NODE_CMMH:-1}
CONFIG_DIR=${CONFIG_DIR:-config2}

RUN_DIR=${RUN_DIR:-try}
echo $RUN_DIR
TIMESTAMP=${TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}
LOG_FILE=${LOG_FILE:-benchmark_run_${TIMESTAMP}.log}

RECORD_COUNT=${RECORD_COUNT:-60000000}
OPERATION_COUNT=${OPERATION_COUNT:-60000000}
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
MAX_EXECUTION_TIME=${MAX_EXECUTION_TIME:-120}

DISTRIBUTIONS=(zipfian)
if [[ -n "${THREAD_COUNTS_STR:-}" ]]; then
  read -ra THREAD_COUNTS <<< "$THREAD_COUNTS_STR"
else
  THREAD_COUNTS=(1 4 8 16 32)
fi
MEMORY_MODES=(cmmh)   # add "local" if needed

# runner script + redis config (override via env)
RUN_FIX=${RUN_FIX:-./run-fix-simple.sh}
REDIS_CONF=${REDIS_CONF:-./redis2.conf}
export REDIS_CONF

# KV Size configurations: kv_label -> fieldcount:fieldlength
# Example: KV_CONFIGS["1kb"]="10:100"
declare -A KV_CONFIGS
KV_CONFIGS["1kb"]="10:100"

# Deterministic KV order (edit if you add more)
KV_ORDER=("1kb")

mkdir -p "$CONFIG_DIR"

log() {
  local msg="$1"
  echo -e "$msg"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${msg//\x1b\[[0-9;]*m/}" >> "$LOG_FILE" || true
}

get_node() {
  case "$1" in
    local) echo "$NODE_LOCAL";;
    cmmh)  echo "$NODE_CMMH";;
    *)     echo "$NODE_LOCAL";;
  esac
}

create_load_config() {
  local kv_label="$1" field_count="$2" field_length="$3"
  local filename="$CONFIG_DIR/redis-load-${kv_label}.properties"
  cat > "$filename" <<EOF2
recordcount=$RECORD_COUNT
operationcount=$OPERATION_COUNT
redis.host=$REDIS_HOST
redis.port=$REDIS_PORT
fieldcount=$field_count
fieldlength=$field_length
threadcount=64
EOF2
}

create_run_config() {
  local kv_label="$1" field_count="$2" field_length="$3" thread_count="$4" distribution="$5"
  local filename="$CONFIG_DIR/redis-run-${MAX_EXECUTION_TIME}-${kv_label}-${thread_count}t-${distribution}.properties"
  cat > "$filename" <<EOF2
recordcount=$RECORD_COUNT
operationcount=$OPERATION_COUNT
redis.host=$REDIS_HOST
redis.port=$REDIS_PORT
fieldcount=$field_count
fieldlength=$field_length
threadcount=$thread_count
hdrhistogram.percentiles=5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,99,99.9,99.99,99.999,100
requestdistribution=$distribution
EOF2
}

cleanup_between_kv() {
  sudo killall redis-server 2>/dev/null || true
  sleep 2
}

cleanup_all() {
  sudo killall -9 redis-server 2>/dev/null || true
  sudo killall -9 pcm-memory 2>/dev/null || true
  sudo killall -9 perf 2>/dev/null || true
}

generate_configs() {
  log "Generating configs into: $CONFIG_DIR"
  for kv_label in "${KV_ORDER[@]}"; do
    IFS=':' read -r field_count field_length <<< "${KV_CONFIGS[$kv_label]}"
    create_load_config "$kv_label" "$field_count" "$field_length"
    for dist in "${DISTRIBUTIONS[@]}"; do
      for t in "${THREAD_COUNTS[@]}"; do
        create_run_config "$kv_label" "$field_count" "$field_length" "$t" "$dist"
      done
    done
  done
}

load_once() {
  local memory_mode="$1" dist="$2" kv_label="$3" node="$4"
  local load_exp="LOAD-${memory_mode}-${dist}-${kv_label}-${TIMESTAMP}"
  local load_cfg="$CONFIG_DIR/redis-load-${kv_label}.properties"

  log "LOAD: $load_exp (node=$node)"
  "$RUN_FIX" "$load_exp" "$load_cfg" dummy_run_config "$node" load

  local target_dir="$RUN_DIR/$dist/${memory_mode}-${kv_label}/LOAD"
  mkdir -p "$target_dir"
  [[ -d "$load_exp" ]] && mv "$load_exp" "$target_dir/" || true
}

run_all_threads() {
  local memory_mode="$1" dist="$2" kv_label="$3" node="$4"
  for t in "${THREAD_COUNTS[@]}"; do
    local run_exp="RUN-${memory_mode}-${dist}-${kv_label}-${t}t-${TIMESTAMP}"
    local run_cfg="$CONFIG_DIR/redis-run-${MAX_EXECUTION_TIME}-${kv_label}-${t}t-${dist}.properties"

    log "RUN: $run_exp (node=$node)"
    "$RUN_FIX" "$run_exp" dummy_load_config "$run_cfg" "$node" run

    local target_dir="$RUN_DIR/$dist/${memory_mode}-${kv_label}/${t}t"
    mkdir -p "$target_dir"
    [[ -d "$run_exp" ]] && mv "$run_exp" "$target_dir/" || true
    sleep 1
  done
}

main() {
  if [[ ! -f "$RUN_FIX" ]]; then
    echo "ERROR: $RUN_FIX not found (expected in current directory)." >&2
    exit 1
  fi
  if [[ ! -f "$REDIS_CONF" ]]; then
    echo "ERROR: Redis config not found: $REDIS_CONF" >&2
    exit 1
  fi
  chmod +x "$RUN_FIX" || true

  generate_configs

  local total_kv=${#KV_ORDER[@]}
  log "Starting benchmarks: kv=$total_kv dist=${#DISTRIBUTIONS[@]} mem=${#MEMORY_MODES[@]} threads=${#THREAD_COUNTS[@]}"

  for kv_label in "${KV_ORDER[@]}"; do
    for dist in "${DISTRIBUTIONS[@]}"; do
      for memory_mode in "${MEMORY_MODES[@]}"; do
        local node
        node=$(get_node "$memory_mode")

        cleanup_between_kv
        cleanup_all

        load_once "$memory_mode" "$dist" "$kv_label" "$node"
        run_all_threads "$memory_mode" "$dist" "$kv_label" "$node"

        cleanup_between_kv
        cleanup_all
      done
    done
  done

  log "All benchmarks done. Results under: $RUN_DIR"
}

trap 'echo "Interrupted"; cleanup_all; exit 1' INT
main
