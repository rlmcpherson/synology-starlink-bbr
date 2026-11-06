#!/usr/bin/env bash
# Wait for the VM to accept SSH, then wait for cloud-init and print a summary.
# Usage: vm/status.sh [max-seconds]
set -uo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

max=${1:-600}
for ((t = 0; t < max; t += 10)); do
  if vm_ssh -o ConnectTimeout=5 true 2>/dev/null; then
    vm_ssh 'cloud-init status --wait --long; uname -r; cat /proc/sys/net/ipv4/tcp_congestion_control; dpkg-query -W haproxy iperf3 qemu-guest-agent'
    exit $?
  fi
  sleep 10
done
echo "no SSH to $VM_USER@$VM_IP after ${max}s. Check the VM's IP in UniFi or VMM, or run vm/console.sh" >&2
exit 1
