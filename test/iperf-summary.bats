setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  FIX=$BATS_TEST_DIRNAME/fixtures
}

@test "summarizes a single run" {
  run "$ROOT/bench/iperf-summary.sh" cubic "$FIX/iperf-1.json"
  [ "$status" -eq 0 ]
  [ "$output" = "cubic: runs 1, avg 11 Mbps, worst 1s 5 Mbps, retransmits 120" ]
}

@test "aggregates runs: mean of averages, worst interval overall, summed retransmits" {
  run "$ROOT/bench/iperf-summary.sh" cubic "$FIX/iperf-1.json" "$FIX/iperf-2.json"
  [ "$status" -eq 0 ]
  [ "$output" = "cubic: runs 2, avg 9.2 Mbps, worst 1s 0.8 Mbps, retransmits 200" ]
}

@test "treats missing retransmits as zero" {
  run "$ROOT/bench/iperf-summary.sh" bbr "$FIX/iperf-no-retrans.json"
  [ "$status" -eq 0 ]
  [ "$output" = "bbr: runs 1, avg 43.5 Mbps, worst 1s 40 Mbps, retransmits 0" ]
}

@test "prints usage without results" {
  run "$ROOT/bench/iperf-summary.sh" cubic
  [ "$status" -eq 2 ]
  [[ $output == usage:* ]]
}
