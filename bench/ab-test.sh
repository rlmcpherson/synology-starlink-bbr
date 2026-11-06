#!/usr/bin/env bash
# A/B test the VM's congestion control over the real path, alternating CUBIC and BBR.
# Run from a client on the slow link. Needs a temporary gateway forward of IPERF_PORT to the VM.
# Usage: bench/ab-test.sh [rounds] [seconds]
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

rounds=${1:-3}
secs=${2:-30}
port=${IPERF_PORT:-5201}
out=$(mktemp -d)

cleanup() {
  vm_ssh "sudo sysctl -q -w net.ipv4.tcp_congestion_control=bbr; pkill -x iperf3 || true" || true
  echo "raw results: $out (run bench/scrub-results.sh on them before sharing)"
}
trap cleanup EXIT

vm_ssh "pkill -x iperf3 || true; iperf3 -s -D -p $port"

for r in $(seq 1 "$rounds"); do
  for cc in cubic bbr; do
    vm_ssh "sudo sysctl -q -w net.ipv4.tcp_congestion_control=$cc"
    iperf3 -c "$PUBLIC_HOST" -p "$port" -R -P 1 -t "$secs" -J > "$out/$cc-$r.json"
    "$REPO_ROOT/bench/iperf-summary.sh" "$cc round $r" "$out/$cc-$r.json"
  done
done

echo "---"
"$REPO_ROOT/bench/iperf-summary.sh" cubic "$out"/cubic-*.json
"$REPO_ROOT/bench/iperf-summary.sh" bbr "$out"/bbr-*.json
