#!/usr/bin/env bash
# Summarize `ss -tinH` output from stdin: one line per connection.
set -euo pipefail

awk '
  /^[^ \t]/ { peer = $NF; next }
  {
    cc = "?"; rtt = "-"; rate = "-"; retr = "0"; sent = "-"
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^(bbr|bbr2|cubic|reno)$/) cc = $i
      else if ($i ~ /^rtt:/) { split(substr($i, 5), r, "/"); rtt = r[1] "ms" }
      else if ($i == "delivery_rate") rate = $(i + 1)
      else if ($i ~ /^retrans:/) { split(substr($i, 9), r, "/"); retr = r[2] }
      else if ($i ~ /^bytes_sent:/) sent = sprintf("%.1fMB", substr($i, 12) / 1e6)
    }
    printf "%-22s %-6s rtt %-9s rate %-12s sent %-9s retrans %s\n", peer, cc, rtt, rate, sent, retr
  }
'
