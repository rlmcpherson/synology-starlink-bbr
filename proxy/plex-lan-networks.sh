#!/usr/bin/env bash
# Print the value for Plex > Settings > Network > LAN Networks: LAN_CIDR minus VM_IP.
# Proxied clients arrive from VM_IP, so leaving it out keeps them classified as Remote.
# Append any other local subnets (VLANs) yourself.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

die() {
  echo "$*" >&2
  exit 1
}

ip2int() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  for o in "$a" "$b" "$c" "$d"; do
    if [[ ! $o =~ ^[0-9]+$ ]] || ((o > 255)); then
      die "bad IPv4 address: $1"
    fi
  done
  echo $(((a << 24) | (b << 16) | (c << 8) | d))
}

int2ip() {
  echo "$((($1 >> 24) & 255)).$((($1 >> 16) & 255)).$((($1 >> 8) & 255)).$(($1 & 255))"
}

[[ $LAN_CIDR =~ ^[0-9.]+/[0-9]+$ ]] || die "bad LAN_CIDR: $LAN_CIDR"
prefix=${LAN_CIDR#*/}
((prefix >= 1 && prefix <= 31)) || die "LAN_CIDR prefix must be 1-31: $LAN_CIDR"
net=$(ip2int "${LAN_CIDR%/*}")
vm=$(ip2int "$VM_IP")
mask=$(((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF))
(((net & mask) == net)) || die "LAN_CIDR has host bits set: $LAN_CIDR"
(((vm & mask) == net)) || die "VM_IP $VM_IP is not inside LAN_CIDR $LAN_CIDR"

# At each prefix length, the half not containing the VM is all LAN.
out=()
for ((b = prefix + 1; b <= 32; b++)); do
  bmask=$(((0xFFFFFFFF << (32 - b)) & 0xFFFFFFFF))
  out+=("$(int2ip $(((vm ^ (1 << (32 - b))) & bmask)))/$b")
done
(
  IFS=,
  echo "${out[*]}"
)
