#!/usr/bin/env bash
# Gracefully reboot the VM through libvirt on the NAS.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=vmm.sh
source "$REPO_ROOT/vm/vmm.sh"

id=$(vm_guest_id)
[[ -n $id ]] || { echo "no VMM guest named $VM_HOSTNAME" >&2; exit 1; }
nas_ssh "$VIRSH reboot $id"
