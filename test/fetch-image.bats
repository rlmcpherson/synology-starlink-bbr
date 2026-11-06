load helpers/stub-nas

WANT=aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a

setup() {
  setup_stub_nas
}

teardown() {
  teardown_stub_nas
}

@test "downloads with redirects, verifies, then renames to .img" {
  STUB_SHA_PART=$WANT run "$ROOT/vm/fetch-image.sh"
  [ "$status" -eq 0 ]
  called "curl -fsSL -o '/volume1/homes/admin/starlink-proxy/debian-13-generic-amd64.img.part' 'https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.raw'"
  called "mv '/volume1/homes/admin/starlink-proxy/debian-13-generic-amd64.img.part' '/volume1/homes/admin/starlink-proxy/debian-13-generic-amd64.img'"
}

@test "skips the download when a verified image is already there" {
  STUB_SHA_EXISTING=$WANT run "$ROOT/vm/fetch-image.sh"
  [ "$status" -eq 0 ]
  [[ $output == *"already present"* ]]
  run called "curl -fsSL -o"
  [ "$status" -ne 0 ]
}

@test "fails without renaming on checksum mismatch" {
  STUB_SHA_PART=deadbeef run "$ROOT/vm/fetch-image.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"checksum mismatch"* ]]
  run called "mv "
  [ "$status" -ne 0 ]
}

@test "fails when the image is missing from SHA512SUMS" {
  printf 'abc  something-else.raw\n' > "$BIN/sums"
  STUB_SUMS=$BIN/sums run "$ROOT/vm/fetch-image.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"no checksum"* ]]
  [ ! -s "$CALLS" ]
}
