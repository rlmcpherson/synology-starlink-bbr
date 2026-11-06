#!/usr/bin/env bash
# Measure real send throughput of the busiest proxied connection from bytes_sent deltas.
# Usage: bench/stream-rate.sh [seconds] [interval] [port]
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

dur=${1:-30}
step=${2:-5}
port=${3:-32400}

# Print "peer bytes_sent" for each connection.
sample() {
  vm_ssh "ss -tinH state established '( sport = :$port )'" | awk '
    /^[^ \t]/ { peer = $NF; next }
    { for (i = 1; i <= NF; i++) if ($i ~ /^bytes_sent:/) print peer, substr($i, 12) }'
}

prev=$(sample)
peer=$(sort -k2 -n <<< "$prev" | tail -1 | cut -d' ' -f1)
[[ -n $peer ]] || { echo "no connections on :$port" >&2; exit 1; }
last=$(awk -v p="$peer" '$1 == p {print $2}' <<< "$prev")
t_last=$EPOCHREALTIME
t0=$t_last
first=$last
echo "busiest connection: $peer"

# Each sample costs an SSH round trip, so rates use measured time, not the nominal step.
end=$(echo "$t0 + $dur" | bc -l)
while (($(echo "$EPOCHREALTIME < $end" | bc -l))); do
  sleep "$step"
  now=$(awk -v p="$peer" '$1 == p {print $2}' <<< "$(sample)")
  t_now=$EPOCHREALTIME
  if [[ -z $now ]]; then
    echo "connection closed"
    break
  fi
  printf '%5.1fs  %6.1f Mbps\n' "$(echo "$t_now - $t0" | bc -l)" \
    "$(echo "($now - $last) * 8 / ($t_now - $t_last) / 1000000" | bc -l)"
  last=$now
  t_last=$t_now
done
printf 'avg %.1f Mbps over %.0fs\n' \
  "$(echo "($last - $first) * 8 / ($t_last - $t0) / 1000000" | bc -l)" "$(echo "$t_last - $t0" | bc -l)"
