#!/usr/bin/env bash
# Save a screenshot of the VM console to build/console.png. Useful when the VM never reaches the network.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=vmm.sh
source "$REPO_ROOT/vm/vmm.sh"

id=$(vm_guest_id)
[[ -n $id ]] || { echo "no VMM guest named $VM_HOSTNAME" >&2; exit 1; }
mkdir -p "$REPO_ROOT/build"
nas_ssh "$VIRSH screenshot $id /tmp/$VM_HOSTNAME-console.png >/dev/null"
nas_ssh "sudo cat /tmp/$VM_HOSTNAME-console.png" > "$REPO_ROOT/build/console.png"
echo "$REPO_ROOT/build/console.png"
