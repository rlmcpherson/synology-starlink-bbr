setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  TMP=$(mktemp -d)
  cat > "$TMP/r.json" <<'EOF'
{
  "start": {
    "connected": [{"socket": 6, "local_host": "10.9.8.7", "local_port": 6000, "remote_host": "198.51.100.77", "remote_port": 5201}],
    "system_info": "Darwin my-laptop.local 25.4.0",
    "connecting_to": {"host": "home.private.example", "port": 5201},
    "cookie": "secretcookie"
  },
  "intervals": [{"sum": {"bits_per_second": 1000}}],
  "end": {"sender_tcp_congestion": "bbr", "sum_received": {"bits_per_second": 1000}}
}
EOF
}

teardown() {
  rm -rf "$TMP"
}

@test "removes hosts, IPs, machine info and cookie, keeps measurements" {
  run "$ROOT/bench/scrub-results.sh" "$TMP/r.json"
  [ "$status" -eq 0 ]
  run grep -E '10\.9\.8\.7|198\.51\.100\.77|my-laptop|home\.private|secretcookie' "$TMP/r.json"
  [ "$status" -ne 0 ]
  [ "$(jq -r .start.connected[0].remote_port "$TMP/r.json")" = 5201 ]
  [ "$(jq -r .end.sender_tcp_congestion "$TMP/r.json")" = bbr ]
  [ "$(jq -r .end.sum_received.bits_per_second "$TMP/r.json")" = 1000 ]
}

@test "committed results only contain placeholder hosts" {
  for f in "$ROOT"/bench/results/*/*.json; do
    run jq -e '
      .start.system_info == "redacted" and .start.cookie == "redacted"
      and .start.connecting_to.host == "nas.example.net"
      and all(.start.connected[]; .local_host == "192.0.2.10" and .remote_host == "203.0.113.10")
    ' "$f"
    [ "$status" -eq 0 ]
  done
}
