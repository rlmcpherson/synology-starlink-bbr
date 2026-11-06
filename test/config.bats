setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  export CONFIG=$BATS_TEST_DIRNAME/fixtures/config.env
}

ip2int() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  echo $(((a << 24) | (b << 16) | (c << 8) | d))
}

# Assert the CIDR list covers LAN_CIDR exactly once per address, except VM_IP.
assert_covers_lan_except_vm() {
  local list=$1 lan=$2 vm=$3 c start bits size i
  local lan_start lan_size
  lan_start=$(ip2int "${lan%/*}")
  lan_size=$((1 << (32 - ${lan#*/})))
  declare -A seen
  IFS=, read -ra cidrs <<< "$list"
  for c in "${cidrs[@]}"; do
    start=$(ip2int "${c%/*}")
    bits=${c#*/}
    size=$((1 << (32 - bits)))
    [ $((start % size)) -eq 0 ]
    for ((i = start; i < start + size; i++)); do
      [ -z "${seen[$i]:-}" ]
      seen[$i]=1
    done
  done
  for ((i = lan_start; i < lan_start + lan_size; i++)); do
    if [ "$i" -eq "$(ip2int "$vm")" ]; then
      [ -z "${seen[$i]:-}" ]
    else
      [ -n "${seen[$i]:-}" ]
    fi
  done
  [ "${#seen[@]}" -eq $((lan_size - 1)) ]
}

@test "LAN Networks for a /24 with the VM at .254" {
  run "$ROOT/proxy/plex-lan-networks.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "192.168.1.0/25,192.168.1.128/26,192.168.1.192/27,192.168.1.224/28,192.168.1.240/29,192.168.1.248/30,192.168.1.252/31,192.168.1.255/32" ]
  assert_covers_lan_except_vm "$output" 192.168.1.0/24 192.168.1.254
}

@test "LAN Networks for a /23 with the VM low in the range" {
  LAN_CIDR=10.0.4.0/23 VM_IP=10.0.4.2 run "$ROOT/proxy/plex-lan-networks.sh"
  [ "$status" -eq 0 ]
  assert_covers_lan_except_vm "$output" 10.0.4.0/23 10.0.4.2
}

@test "LAN Networks for a /16" {
  LAN_CIDR=172.16.0.0/16 VM_IP=172.16.200.9 run "$ROOT/proxy/plex-lan-networks.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "172.16.0.0/17,172.16.128.0/18,172.16.224.0/19,172.16.208.0/20,172.16.192.0/21,172.16.204.0/22,172.16.202.0/23,172.16.201.0/24,172.16.200.128/25,172.16.200.64/26,172.16.200.32/27,172.16.200.16/28,172.16.200.0/29,172.16.200.12/30,172.16.200.10/31,172.16.200.8/32" ]
}

@test "rejects a VM outside the LAN" {
  VM_IP=192.168.2.5 run "$ROOT/proxy/plex-lan-networks.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"not inside LAN_CIDR"* ]]
}

@test "rejects a LAN_CIDR with host bits set" {
  LAN_CIDR=192.168.1.7/24 run "$ROOT/proxy/plex-lan-networks.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"host bits"* ]]
}

@test "rejects a malformed address" {
  VM_IP=192.168.1.300 run "$ROOT/proxy/plex-lan-networks.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"bad IPv4 address"* ]]
}

@test "example config uses a VM user that is not a Debian system account" {
  source "$ROOT/config.env.example"
  [[ " root daemon bin sys sync games man lp mail news uucp proxy www-data backup list irc _apt nobody " != *" $VM_USER "* ]]
}
