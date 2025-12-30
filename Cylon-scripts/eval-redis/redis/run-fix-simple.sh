#!/usr/bin/env bash
set -euo pipefail

# Redis + YCSB runner (hugepage-focused, minimal).
# Usage:
#   ./run-fix-simple.sh <experiment_name> <load_config> <run_config> <redis_numa_node> [mode]
# mode: load | run | both (default)

EXPERIMENT_NAME=${1:-"test-$(date +%Y%m%d-%H%M%S)"}
LOAD_CONFIG=${2:-""}
RUN_CONFIG=${3:-""}
REDIS_NUMA_NODE=${4:-"0"}
MODE=${5:-"both"}

LOG_DIR=${LOG_DIR:-"./${EXPERIMENT_NAME}"}
REDIS_CONF=${REDIS_CONF:-"./redis2.conf"}

# Paths (override via env if your paths differ)
REDIS_SERVER=${REDIS_SERVER:-"/root/redis-8.0.0/src/redis-server"}
REDIS_CLI=${REDIS_CLI:-"/root/redis-8.0.0/src/redis-cli"}
YCSB_BIN=${YCSB_BIN:-"/root/YCSB/redis/target/ycsb-redis-binding-0.18.0-SNAPSHOT/bin/ycsb"}
YCSB_WORKLOAD=${YCSB_WORKLOAD:-"/root/YCSB/redis/target/ycsb-redis-binding-0.18.0-SNAPSHOT/workloads/workloadc"}

# CPU/mem binding for the YCSB client (matches your original script)
CLIENT_CPU_NODE=${CLIENT_CPU_NODE:-0}
CLIENT_MEM_NODE=${CLIENT_MEM_NODE:-0}

# perf stat (optional)
# ENABLE_PERF=${ENABLE_PERF:-1}
# PERF=${PERF:-"/root/linux/tools/perf/perf"}
# PERF_INTERVAL_MS=${PERF_INTERVAL_MS:-2000}
# PERF_EVENTS=${PERF_EVENTS:-"instructions,cycles,MEM_BOUND_STALLS_LOAD.ALL,TOPDOWN_BE_BOUND.REORDER_BUFFER,TOPDOWN_BE_BOUND.NON_MEM_SCHEDULER,TOPDOWN_BE_BOUND.MEM_SCHEDULER"}

# Hugepage allocator (tcmalloc memfs)
# ENABLE_TCMALLOC=${ENABLE_TCMALLOC:-1}
# TCMALLOC_LIB=${TCMALLOC_LIB:-"/root/gperftools/build/libtcmalloc.so"}
# TCMALLOC_MEMFS_MALLOC_PATH=${TCMALLOC_MEMFS_MALLOC_PATH:-"/mnt/hugetlbfs/"}

mkdir -p "$LOG_DIR"

pid_perf=0

cleanup_redis() {
  # Stop perf if running
  if [[ $pid_perf -ne 0 ]]; then
    sudo kill -INT "$pid_perf" 2>/dev/null || true
    pid_perf=0
  fi
  # Stop redis
  sudo killall -9 redis-server 2>/dev/null || true
}

redis_ping_ok() {
  "$REDIS_CLI" ping 2>/dev/null | grep -q PONG
}

start_redis_server_fresh() {
  # wipe persisted state (matches your original behavior)
  local data_dir=${REDIS_DATA_DIR:-"/tdata/redis"}
  sudo rm -f "$data_dir"/dump.rdb "$data_dir"/*.rdb "$data_dir"/appendonly.aof "$data_dir"/redis-server.pid 2>/dev/null || true
  sudo rm -f dump.rdb appendonly.aof 2>/dev/null || true

  # allocator
  # if [[ "$ENABLE_TCMALLOC" == "1" ]]; then
  #   export LD_PRELOAD="$TCMALLOC_LIB"
  #   export TCMALLOC_MEMFS_MALLOC_PATH="$TCMALLOC_MEMFS_MALLOC_PATH"
  # else
  #   unset LD_PRELOAD
  # fi

  # start redis
  numactl --cpunodebind 0 --membind "$REDIS_NUMA_NODE" -- "$REDIS_SERVER" "$REDIS_CONF" &
  local redis_pid=$!
  echo "Redis PID: $redis_pid" | tee -a "$LOG_DIR/${EXPERIMENT_NAME}_meta.txt"

  # wait ready
  local timeout_s=${REDIS_START_TIMEOUT_S:-120}
  local waited=0
  while [[ $waited -lt $timeout_s ]]; do
    if redis_ping_ok; then
      echo "Redis ready after ${waited}s" | tee -a "$LOG_DIR/${EXPERIMENT_NAME}_meta.txt"
      return 0
    fi
    sleep 2
    waited=$((waited+2))
  done
  echo "ERROR: Redis not ready after ${timeout_s}s" >&2
  return 1
}

start_perf_on_redis() {
  [[ "$ENABLE_PERF" == "1" ]] || return 0

  # Try PID from pidfile first (your original script relied on this)
  local pid_file=${REDIS_PID_FILE:-"/tdata/redis/redis-server.pid"}
  local redis_pid=""
  if [[ -f "$pid_file" ]]; then
    redis_pid=$(cat "$pid_file" 2>/dev/null || true)
  fi
  # fallback: pgrep
  if [[ -z "$redis_pid" ]]; then
    redis_pid=$(pgrep -n redis-server || true)
  fi
  if [[ -z "$redis_pid" ]]; then
    echo "WARNING: perf enabled but cannot find redis PID. Skipping perf." >&2
    return 0
  fi

  sudo "$PERF" stat -e "$PERF_EVENTS" -I "$PERF_INTERVAL_MS" -p "$redis_pid" \
    -o "$LOG_DIR/${EXPERIMENT_NAME}_run_perf.txt" \
    > /dev/null 2> "$LOG_DIR/${EXPERIMENT_NAME}_run_perf_stderr.log" &
  pid_perf=$!
}

load_data() {
  [[ -f "$LOAD_CONFIG" ]] || { echo "ERROR: load config not found: $LOAD_CONFIG" >&2; return 1; }

  echo "Starting YCSB LOAD with config: $LOAD_CONFIG"
  sudo numactl --cpunodebind "$CLIENT_CPU_NODE" --membind "$CLIENT_MEM_NODE" -- \
    "$YCSB_BIN" load redis -s \
    -P "$YCSB_WORKLOAD" \
    -P "$LOAD_CONFIG" \
    -p redis.timeout=1800000000 \
    -p measurementtype=raw \
    -p measurement.raw.output_file="$LOG_DIR/${EXPERIMENT_NAME}_load.log" \
    > "$LOG_DIR/${EXPERIMENT_NAME}_load_output.txt" 2>&1
  echo "Finished YCSB LOAD"
}

run_workload() {
  [[ -f "$RUN_CONFIG" ]] || { echo "ERROR: run config not found: $RUN_CONFIG" >&2; return 1; }

  #start_perf_on_redis

  sudo numactl --cpunodebind "$CLIENT_CPU_NODE" --membind "$CLIENT_MEM_NODE" -- \
    "$YCSB_BIN" run redis -s \
    -P "$YCSB_WORKLOAD" \
    -P "$RUN_CONFIG" \
    -p redis.timeout=1800000000 \
    -p measurementtype=raw \
    -p measurement.raw.output_file="$LOG_DIR/${EXPERIMENT_NAME}_run.log" \
    > "$LOG_DIR/${EXPERIMENT_NAME}_run_output.txt" 2>&1

  # stop perf
  if [[ $pid_perf -ne 0 ]]; then
    sudo kill -INT "$pid_perf" 2>/dev/null || true
    pid_perf=0
  fi

  # drop caches (kept from your original)
  sync
  echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
}

main() {
  echo "=== Redis Benchmark Experiment: $EXPERIMENT_NAME (mode=$MODE) ===" | tee "$LOG_DIR/${EXPERIMENT_NAME}_meta.txt"
  echo "redis_conf=$REDIS_CONF redis_numa=$REDIS_NUMA_NODE client_cpu=$CLIENT_CPU_NODE client_mem=$CLIENT_MEM_NODE" | tee -a "$LOG_DIR/${EXPERIMENT_NAME}_meta.txt"

  case "$MODE" in
    load)
      #trap cleanup_redis EXIT
      #cleanup_redis
      start_redis_server_fresh
      load_data
      # intentionally keep redis running
      ;;
    run)
      redis_ping_ok || { echo "ERROR: Redis not running / not responsive. Run load phase first." >&2; exit 1; }
      run_workload
      ;;
    both|*)
      trap cleanup_redis EXIT
      cleanup_redis
      start_redis_server_fresh
      load_data
      run_workload
      cleanup_redis
      ;;
  esac

  echo "Done. Logs in: $LOG_DIR" | tee -a "$LOG_DIR/${EXPERIMENT_NAME}_meta.txt"
}

main
