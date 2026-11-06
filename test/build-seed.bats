setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  export CONFIG=$BATS_TEST_DIRNAME/fixtures/config.env
  TMP=$(mktemp -d)
  KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample+/key me&co@host'
  printf '%s\n' "$KEY" > "$TMP/key.pub"
}

teardown() {
  rm -rf "$TMP"
}

@test "renders key, user and hostname into user-data" {
  run "$ROOT/vm/build-seed.sh" "$TMP/key.pub" "$TMP/out"
  [ "$status" -eq 0 ]
  grep -qxF -- "      - $KEY" "$TMP/out/seed/user-data"
  grep -qx '  - name: ops' "$TMP/out/seed/user-data"
  grep -qx 'hostname: starlink-proxy' "$TMP/out/seed/user-data"
  grep -qx 'local-hostname: starlink-proxy' "$TMP/out/seed/meta-data"
  grep -qE '^instance-id: starlink-proxy-[0-9]{14}$' "$TMP/out/seed/meta-data"
  run grep -l '__' "$TMP/out/seed/user-data" "$TMP/out/seed/meta-data"
  [ "$status" -ne 0 ]
}

@test "builds an ISO labelled cidata" {
  run "$ROOT/vm/build-seed.sh" "$TMP/key.pub" "$TMP/out"
  [ "$status" -eq 0 ]
  label=$(dd if="$TMP/out/seed.iso" bs=1 skip=32808 count=32 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  [ "$label" = cidata ]
}

@test "ISO contains user-data and meta-data" {
  command -v xorriso >/dev/null || skip "xorriso not installed"
  "$ROOT/vm/build-seed.sh" "$TMP/key.pub" "$TMP/out"
  run xorriso -indev "$TMP/out/seed.iso" -find / -type f
  [[ $output == *"'/user-data'"* ]]
  [[ $output == *"'/meta-data'"* ]]
}

@test "user-data passes cloud-init schema validation" {
  command -v cloud-init >/dev/null || skip "cloud-init not installed"
  "$ROOT/vm/build-seed.sh" "$TMP/key.pub" "$TMP/out"
  run cloud-init schema --config-file "$TMP/out/seed/user-data"
  [ "$status" -eq 0 ]
}

@test "rejects a private key" {
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\n' > "$TMP/key"
  run "$ROOT/vm/build-seed.sh" "$TMP/key" "$TMP/out"
  [ "$status" -eq 1 ]
  [[ $output == *"not an SSH public key"* ]]
  [ ! -e "$TMP/out" ]
}

@test "rejects a Debian system account as VM user" {
  VM_USER=proxy run "$ROOT/vm/build-seed.sh" "$TMP/key.pub" "$TMP/out"
  [ "$status" -eq 1 ]
  [[ $output == *"Debian system account"* ]]
  [ ! -e "$TMP/out" ]
}

@test "each build gets a new instance-id" {
  "$ROOT/vm/build-seed.sh" "$TMP/key.pub" "$TMP/a"
  sleep 1
  "$ROOT/vm/build-seed.sh" "$TMP/key.pub" "$TMP/b"
  run cmp -s "$TMP/a/seed/meta-data" "$TMP/b/seed/meta-data"
  [ "$status" -ne 0 ]
}

@test "rejects a missing key file" {
  run "$ROOT/vm/build-seed.sh" "$TMP/nope.pub" "$TMP/out"
  [ "$status" -eq 1 ]
  [[ $output == *"missing public key"* ]]
}
