load helpers/stub-nas

setup() {
  setup_stub_nas
}

teardown() {
  teardown_stub_nas
}

@test "finds the guest disk, writes, verifies, then resets" {
  run "$ROOT/vm/write-disk.sh"
  [ "$status" -eq 0 ]
  called "domblklist 5a0891b7-7fcf-4eb8-b3a8-ba1c0fbc51c0"
  called "sudo cmp -s -n 3221225472 '/dev/iscsi1' /dev/zero"
  called "sudo dd if='/volume1/homes/admin/starlink-proxy/debian-13-generic-amd64.img' of='/dev/iscsi1'"
  called "reset 5a0891b7-7fcf-4eb8-b3a8-ba1c0fbc51c0"
  dd_line=$(grep -n 'dd if=' "$CALLS" | cut -d: -f1)
  reset_line=$(grep -n ' reset ' "$CALLS" | cut -d: -f1)
  [ "$dd_line" -lt "$reset_line" ]
}

@test "refuses to overwrite a disk that is not blank" {
  STUB_BLANK_EXIT=1 run "$ROOT/vm/write-disk.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"not blank"* ]]
  run called "dd if="
  [ "$status" -ne 0 ]
}

@test "refuses a disk smaller than the image" {
  STUB_DEV_SIZE=1048576 run "$ROOT/vm/write-disk.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"smaller than"* ]]
  run called "dd if="
  [ "$status" -ne 0 ]
}

@test "does not reset when verification fails" {
  STUB_VERIFY_EXIT=1 run "$ROOT/vm/write-disk.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"verify failed"* ]]
  run called " reset "
  [ "$status" -ne 0 ]
}

@test "reboot.sh reboots the named guest" {
  run "$ROOT/vm/reboot.sh"
  [ "$status" -eq 0 ]
  called "reboot 5a0891b7-7fcf-4eb8-b3a8-ba1c0fbc51c0"
}

@test "fails when no VMM guest has the VM name" {
  sed 's/"starlink-proxy"/"renamed"/' "$FIX/vmm-guest-list.txt" > "$BIN/guests"
  STUB_GUESTS=$BIN/guests run "$ROOT/vm/write-disk.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"no VMM guest named starlink-proxy"* ]]
}
