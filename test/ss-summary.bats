setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "one line per connection with cc, rtt, rate, bytes and retransmits" {
  run "$ROOT/bench/ss-summary.sh" < "$BATS_TEST_DIRNAME/fixtures/ss-tinH.txt"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ ${lines[0]} == "203.0.113.7:57432      bbr    rtt 64.5ms    rate 39.7Mbps     sent 48.2MB    retrans 94" ]]
  [[ ${lines[1]} == "192.168.1.50:51220     cubic  rtt 0.4ms     rate 51.4Mbps     sent 0.0MB     retrans 0" ]]
}

@test "empty input prints nothing" {
  run "$ROOT/bench/ss-summary.sh" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
