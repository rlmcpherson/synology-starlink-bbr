#!/usr/bin/env bash
# Measure NAS-to-client TCP throughput over SSH. No open ports needed.
# Shows the NAS's own (CUBIC) behavior on the current path.
# Usage: bench/sshperf.sh [seconds] [streams]
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

dur=${1:-30}
streams=${2:-1}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

retrans() {
  nas_ssh "awk '/^Tcp:/ && \$2 ~ /^[0-9]/ {print \$13}' /proc/net/snmp"
}

r0=$(retrans)
for i in $(seq 1 "$streams"); do
  (nas_ssh "timeout $dur cat /dev/zero" | wc -c > "$tmp/$i") &
done
wait
r1=$(retrans)

total=0
for i in $(seq 1 "$streams"); do
  b=$(tr -d ' ' < "$tmp/$i")
  printf 'stream %d: %.1f Mbps\n' "$i" "$(echo "$b * 8 / $dur / 1000000" | bc -l)"
  total=$((total + b))
done
printf 'total: %.1f Mbps over %ss, NAS retransmits: %d\n' \
  "$(echo "$total * 8 / $dur / 1000000" | bc -l)" "$dur" "$((r1 - r0))"
