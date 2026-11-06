setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  export CONFIG=$BATS_TEST_DIRNAME/fixtures/config.env
}

@test "renders one listen block per service to the NAS" {
  SERVICES="plex:32400 photos:5443:5001" run "$ROOT/proxy/render-haproxy.sh"
  [ "$status" -eq 0 ]
  [[ $output == *$'listen plex\n    bind :32400\n    server nas 192.168.1.10:32400'* ]]
  [[ $output == *$'listen photos\n    bind :5443\n    server nas 192.168.1.10:5001'* ]]
  [[ $output == "global"* ]]
}

@test "passes haproxy validation" {
  command -v haproxy >/dev/null || skip "haproxy not installed"
  cfg=$(mktemp)
  SERVICES="plex:32400 photos:5443:5001" "$ROOT/proxy/render-haproxy.sh" > "$cfg"
  run haproxy -c -q -f "$cfg"
  rm -f "$cfg"
  [ "$status" -eq 0 ]
}

@test "rejects malformed entries" {
  for bad in "plex" "plex:0" "plex:70000" "plex:abc" "pl ex:1" "plex:1:2:3" "bad/name:80"; do
    SERVICES=$bad run "$ROOT/proxy/render-haproxy.sh"
    [ "$status" -eq 1 ]
  done
}

@test "rejects duplicate ports and names" {
  SERVICES="a:80 b:80" run "$ROOT/proxy/render-haproxy.sh"
  [ "$status" -eq 1 ]
  [[ $output == *duplicate* ]]
  SERVICES="a:80 a:81" run "$ROOT/proxy/render-haproxy.sh"
  [ "$status" -eq 1 ]
}

@test "rejects empty SERVICES" {
  SERVICES=" " run "$ROOT/proxy/render-haproxy.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"SERVICES is empty"* ]]
}
