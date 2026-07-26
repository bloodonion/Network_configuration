#!/bin/bash
#
# 100G Network Benchmark Script
# Usage: ./100g-benchmark.sh <PEER_IP> [label]
# Example: ./100g-benchmark.sh 10.10.10.20 baseline
#          ./100g-benchmark.sh 10.10.10.20 after-tuning

set -euo pipefail

PEER_IP="${1:-}"
LABEL="${2:-test}"
DURATION=30
PARALLEL=8
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULT_DIR="./100g-results"
RESULT_FILE="${RESULT_DIR}/${TIMESTAMP}_${LABEL}.txt"

if [[ -z "$PEER_IP" ]]; then
  echo "Usage: $0 <PEER_IP> [label]"
  echo "Example: $0 10.10.10.20 baseline"
  exit 1
fi

mkdir -p "$RESULT_DIR"

echo "======================================================" | tee "$RESULT_FILE"
echo "100G Benchmark - $LABEL" | tee -a "$RESULT_FILE"
echo "Date      : $(date)" | tee -a "$RESULT_FILE"
echo "Peer      : $PEER_IP" | tee -a "$RESULT_FILE"
echo "Duration  : ${DURATION}s" | tee -a "$RESULT_FILE"
echo "======================================================" | tee -a "$RESULT_FILE"
echo "" | tee -a "$RESULT_FILE"

# --------------------------------------------------
# System information
# --------------------------------------------------
echo "=== System Information ===" | tee -a "$RESULT_FILE"
echo "Hostname     : $(hostname)" | tee -a "$RESULT_FILE"
echo "Kernel       : $(uname -r)" | tee -a "$RESULT_FILE"
echo "Tuned profile: $(tuned-adm active 2>/dev/null || echo 'N/A')" | tee -a "$RESULT_FILE"
echo "CPU Governor : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')" | tee -a "$RESULT_FILE"
echo "" | tee -a "$RESULT_FILE"

echo "=== Key Sysctl ===" | tee -a "$RESULT_FILE"
sysctl net.core.rmem_max net.core.wmem_max net.core.netdev_max_backlog \
       net.core.default_qdisc net.ipv4.tcp_congestion_control 2>/dev/null | tee -a "$RESULT_FILE"
echo "" | tee -a "$RESULT_FILE"

# --------------------------------------------------
# Interface information
# --------------------------------------------------
echo "=== Network Interfaces (100G candidates) ===" | tee -a "$RESULT_FILE"
for iface in $(ls /sys/class/net/ | grep -E '^en|^bond'); do
  speed=$(cat /sys/class/net/$iface/speed 2>/dev/null || echo "unknown")
  mtu=$(cat /sys/class/net/$iface/mtu 2>/dev/null || echo "unknown")
  echo "$iface  speed=${speed}Mb/s  mtu=$mtu" | tee -a "$RESULT_FILE"
done
echo "" | tee -a "$RESULT_FILE"

# --------------------------------------------------
# Helper function
# --------------------------------------------------
run_test() {
  local name="$1"
  local extra_args="$2"

  echo "------------------------------------------------------" | tee -a "$RESULT_FILE"
  echo "TEST: $name" | tee -a "$RESULT_FILE"
  echo "Command: iperf3 -c $PEER_IP -t $DURATION -i 5 $extra_args" | tee -a "$RESULT_FILE"
  echo "------------------------------------------------------" | tee -a "$RESULT_FILE"

  # Run iperf3 and capture output
  iperf3 -c "$PEER_IP" -t "$DURATION" -i 5 $extra_args 2>&1 | tee -a "$RESULT_FILE"

  echo "" | tee -a "$RESULT_FILE"
  sleep 3
}

# --------------------------------------------------
# Run the tests
# --------------------------------------------------
echo "Starting tests against $PEER_IP ..."
echo ""

run_test "Single Stream (TX)" ""
run_test "Single Stream (RX)" "-R"
run_test "8 Parallel Streams (TX)" "-P $PARALLEL"
run_test "8 Parallel Streams (RX)" "-P $PARALLEL -R"
run_test "4 Parallel Streams Bidirectional" "-P 4 --bidir"

# --------------------------------------------------
# Summary of interface counters (optional but useful)
# --------------------------------------------------
echo "=== Interface Error/Drop Counters (after tests) ===" | tee -a "$RESULT_FILE"
for iface in $(ls /sys/class/net/ | grep -E '^en|^bond'); do
  echo "--- $iface ---" | tee -a "$RESULT_FILE"
  ethtool -S "$iface" 2>/dev/null | grep -E 'drop|error|miss|disc|fifo' | grep -v ': 0$' | tee -a "$RESULT_FILE" || true
done
echo "" | tee -a "$RESULT_FILE"

echo "======================================================" | tee -a "$RESULT_FILE"
echo "Benchmark finished." | tee -a "$RESULT_FILE"
echo "Results saved to: $RESULT_FILE" | tee -a "$RESULT_FILE"
echo "======================================================" | tee -a "$RESULT_FILE"

echo ""
echo "Done. Results saved to: $RESULT_FILE"
