#!/usr/bin/env bash
# Summarize iperf3 -J -R results: mean throughput, worst 1s interval, sender retransmits.
# Usage: bench/iperf-summary.sh <label> <result.json>...
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <label> <result.json>..." >&2
  exit 2
fi
label=$1
shift

jq -rs --arg label "$label" '
  def mbps: . / 1e6 * 10 | round / 10;
  "\($label): runs \(length)"
  + ", avg \(map(.end.sum_received.bits_per_second) | add / length | mbps) Mbps"
  + ", worst 1s \([.[].intervals[].sum.bits_per_second] | min | mbps) Mbps"
  + ", retransmits \(map(.end.sum_sent.retransmits // 0) | add)"
' "$@"
