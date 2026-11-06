#!/usr/bin/env bash
# Build the seed ISO and upload it to the NAS. VMM reads the ISO in place,
# so rebooting the VM afterwards reruns cloud-init with the new seed.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

iso=$("$REPO_ROOT/vm/build-seed.sh" "$@")
dest="$NAS_IMAGE_DIR/$VM_HOSTNAME-seed.iso"
nas_ssh "mkdir -p '$NAS_IMAGE_DIR'"
nas_ssh "cat > '$dest'" < "$iso"
echo "$dest"
