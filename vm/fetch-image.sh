#!/usr/bin/env bash
# Download the Debian cloud image onto the NAS and verify its SHA512.
# Saved as .img because VMM's disk image import does not list .raw files.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

img="$NAS_IMAGE_DIR/$DEBIAN_IMAGE.img"
want=$(curl -fsSL "$DEBIAN_IMAGE_URL/SHA512SUMS" | awk -v f="$DEBIAN_IMAGE.raw" '$2 == f {print $1}')
if [[ -z $want ]]; then
  echo "no checksum for $DEBIAN_IMAGE.raw in SHA512SUMS" >&2
  exit 1
fi

nas_ssh "mkdir -p '$NAS_IMAGE_DIR'"
have=$(nas_ssh "if [ -f '$img' ]; then sha512sum '$img' | cut -d' ' -f1; fi")
if [[ $have == "$want" ]]; then
  echo "already present and verified: $img"
  exit 0
fi

# -L: cloud.debian.org redirects to a mirror. Without it curl saves the redirect page.
nas_ssh "curl -fsSL -o '$img.part' '$DEBIAN_IMAGE_URL/$DEBIAN_IMAGE.raw'"
have=$(nas_ssh "sha512sum '$img.part' | cut -d' ' -f1")
if [[ $have != "$want" ]]; then
  echo "checksum mismatch for $img.part" >&2
  exit 1
fi
nas_ssh "mv '$img.part' '$img'"
echo "downloaded and verified: $img"
