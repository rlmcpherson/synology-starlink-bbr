#!/usr/bin/env bash
# Fallback for a VM created with VMM's Create flow, which attaches a blank disk
# ("Boot failed: not a bootable disk"). Writes the Debian image onto the VM's
# virtual disk and resets the VM. Refuses unless that disk region is all zeros.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=vmm.sh
source "$REPO_ROOT/vm/vmm.sh"

img="$NAS_IMAGE_DIR/$DEBIAN_IMAGE.img"

id=$(vm_guest_id)
[[ -n $id ]] || { echo "no VMM guest named $VM_HOSTNAME" >&2; exit 1; }
dev=$(vm_disk_device "$id")
[[ $dev == /dev/* ]] || { echo "no block device for guest $id" >&2; exit 1; }

img_size=$(nas_ssh "stat -c %s '$img'")
dev_size=$(nas_ssh "sudo blockdev --getsize64 '$dev'")
if ((dev_size < img_size)); then
  echo "$dev ($dev_size bytes) is smaller than $img ($img_size bytes)" >&2
  exit 1
fi

if ! nas_ssh "sudo cmp -s -n $img_size '$dev' /dev/zero"; then
  echo "$dev is not blank; refusing to overwrite" >&2
  exit 1
fi

echo "writing $img to $dev (guest $id)"
# conv=sparse skips zero blocks, safe because the target was verified blank.
nas_ssh "sudo dd if='$img' of='$dev' bs=4M conv=sparse,fsync status=none"
nas_ssh "sudo cmp -s -n $img_size '$dev' '$img'" || { echo "verify failed" >&2; exit 1; }
nas_ssh "$VIRSH reset $id"
echo "done; run vm/status.sh"
