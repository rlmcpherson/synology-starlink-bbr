load helpers/stub-nas

setup() {
  setup_stub_nas
}

teardown() {
  teardown_stub_nas
}

@test "tracks the busiest connection and reports positive rates" {
  run "$ROOT/bench/stream-rate.sh" 1 0.2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "busiest connection: 203.0.113.7:27422" ]
  [[ ${lines[1]} =~ ^\ *[0-9.]+s\ +[1-9][0-9.]*\ Mbps$ ]]
  [[ ${lines[-1]} =~ ^avg\ [1-9][0-9.]*\ Mbps\ over\ [0-9]+s$ ]]
}

@test "fails when nothing is connected" {
  STUB_SS_EMPTY=1 run "$ROOT/bench/stream-rate.sh" 1 0.2
  [ "$status" -eq 1 ]
  [[ $output == *"no connections on :32400"* ]]
}
