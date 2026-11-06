#!/usr/bin/env bash
# Replace identifying fields in iperf3 -J results (hosts, IPs, machine info, cookie) so they can be shared.
# Usage: bench/scrub-results.sh <result.json>...   (edits in place)
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <result.json>..." >&2
  exit 2
fi

for f in "$@"; do
  tmp=$(mktemp)
  jq '
    .start.connected |= map(.local_host = "192.0.2.10" | .remote_host = "203.0.113.10")
    | .start.connecting_to.host = "nas.example.net"
    | .start.system_info = "redacted"
    | .start.cookie = "redacted"
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
done
