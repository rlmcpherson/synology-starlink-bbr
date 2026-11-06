setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  export CONFIG=$BATS_TEST_DIRNAME/fixtures/config.env
  BIN=$(mktemp -d)
  # Stub ssh to print one argument per line.
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@"\n' > "$BIN/ssh"
  chmod +x "$BIN/ssh"
  PATH="$BIN:$PATH"
}

teardown() {
  rm -rf "$BIN"
}

has_line() {
  local want=$1 line
  for line in "${lines[@]}"; do
    [ "$line" = "$want" ] && return 0
  done
  echo "missing line: $want" >&2
  return 1
}

@test "nas_ssh targets the NAS with agent forwarding off" {
  source "$ROOT/lib.sh"
  run nas_ssh uptime
  [ "$status" -eq 0 ]
  has_line ForwardAgent=no
  has_line 2200
  has_line admin@nas.example.net
  [ "${lines[-1]}" = uptime ]
}

@test "vm_ssh hops through nc on the NAS when VM_VIA_NAS=1" {
  export VM_VIA_NAS=1
  source "$ROOT/lib.sh"
  run vm_ssh uptime
  [ "$status" -eq 0 ]
  has_line ForwardAgent=no
  has_line "ProxyCommand=ssh -o ForwardAgent=no -o BatchMode=yes -o LogLevel=ERROR -o ServerAliveInterval=15 -p 2200 admin@nas.example.net /var/packages/synocli-net/target/bin/nc %h %p"
  has_line ops@192.168.1.254
  [ "${lines[-1]}" = uptime ]
}

@test "vm_ssh connects directly when VM_VIA_NAS=0" {
  export VM_VIA_NAS=0
  source "$ROOT/lib.sh"
  run vm_ssh uptime
  [ "$status" -eq 0 ]
  [[ $output != *ProxyCommand* ]]
  has_line ops@192.168.1.254
}

@test "a missing config explains what to do" {
  CONFIG=$BIN/nope run bash -c "source '$ROOT/lib.sh'"
  [ "$status" -eq 1 ]
  [[ $output == *"copy config.env.example to config.env"* ]]
}

@test "config.env.example loads" {
  CONFIG=$ROOT/config.env.example run bash -c "source '$ROOT/lib.sh' && echo \"\$VM_HOSTNAME \$SERVICES\""
  [ "$status" -eq 0 ]
  [ "$output" = "starlink-proxy plex:32400" ]
}
