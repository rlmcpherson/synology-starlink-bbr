load helpers/stub-nas

setup() {
  setup_stub_nas
}

teardown() {
  teardown_stub_nas
}

@test "reports QEMU and HAProxy CPU, memory and proxied traffic" {
  run "$ROOT/bench/vm-overhead.sh" 1
  [ "$status" -eq 0 ]
  # Stub: 50 QEMU ticks (0.5s CPU), 5 MB sent, 3 HAProxy ticks per sample pair, 50% NAS idle share.
  [[ $output =~ proxied\ traffic:\ +[1-9][0-9.]*\ Mbps ]]
  [[ $output =~ QEMU\ CPU\ on\ NAS:\ +[1-9][0-9.]*%\ of\ one\ core\ \([0-9.]+%\ of\ all\ 2\ cores\) ]]
  [[ $output =~ HAProxy\ CPU\ in\ VM:\ +[0-9.]+%\ of\ one\ vCPU ]]
  [[ $output == *"NAS CPU busy total:  50.0%"* ]]
  [[ $output == *"QEMU memory on NAS:  1318 MB resident"* ]]
  [[ $output == *"VM memory in use:    280 MB"* ]]
  called "guest=5a0891b7-7fcf-4eb8-b3a8-ba1c0fbc51c0"
}

@test "fails when no VMM guest has the VM name" {
  sed 's/"starlink-proxy"/"renamed"/' "$FIX/vmm-guest-list.txt" > "$BIN/guests"
  STUB_GUESTS=$BIN/guests run "$ROOT/bench/vm-overhead.sh" 1
  [ "$status" -eq 1 ]
  [[ $output == *"no VMM guest named starlink-proxy"* ]]
}
