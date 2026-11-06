#!/usr/bin/env bash
# Build the cloud-init NoCloud seed ISO for the proxy VM.
# Usage: vm/build-seed.sh [ssh-pubkey-file] [out-dir]
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

pubkey_file=${1:-$HOME/.ssh/id_ed25519.pub}
out=${2:-$REPO_ROOT/build}

if [[ ! -f $pubkey_file ]]; then
  echo "missing public key: $pubkey_file" >&2
  exit 1
fi
pubkey=$(<"$pubkey_file")
if [[ ! $pubkey =~ ^(ssh-|ecdsa-|sk-) ]]; then
  echo "not an SSH public key: $pubkey_file" >&2
  exit 1
fi

# Debian base-passwd accounts. cloud-init would reuse one, keeping its nologin shell.
system_users=" root daemon bin sys sync games man lp mail news uucp proxy www-data backup list irc _apt nobody "
if [[ $system_users == *" $VM_USER "* ]]; then
  echo "VM_USER '$VM_USER' is a Debian system account; pick another name" >&2
  exit 1
fi

# A new instance-id makes cloud-init rerun its per-instance setup on the next boot.
instance_id="$VM_HOSTNAME-$(date -u +%Y%m%d%H%M%S)"

# Keep & in replacement strings literal on bash 5.2+.
shopt -u patsub_replacement 2>/dev/null || true

render() {
  local s
  s=$(<"$1")
  s=${s//__SSH_PUBKEY__/$pubkey}
  s=${s//__VM_USER__/$VM_USER}
  s=${s//__HOSTNAME__/$VM_HOSTNAME}
  s=${s//__INSTANCE_ID__/$instance_id}
  printf '%s\n' "$s"
}

make_iso() {
  local src=$1 iso=$2
  rm -f "$iso"
  if command -v hdiutil >/dev/null; then
    hdiutil makehybrid -quiet -iso -joliet -default-volume-name cidata -o "$iso" "$src"
  elif command -v xorriso >/dev/null; then
    xorriso -as mkisofs -quiet -V cidata -J -r -o "$iso" "$src"
  elif command -v genisoimage >/dev/null; then
    genisoimage -quiet -V cidata -J -r -o "$iso" "$src"
  else
    echo "need hdiutil, xorriso or genisoimage" >&2
    return 1
  fi
}

seed=$out/seed
rm -rf "$seed"
mkdir -p "$seed"
render "$REPO_ROOT/vm/user-data.tmpl" > "$seed/user-data"
render "$REPO_ROOT/vm/meta-data.tmpl" > "$seed/meta-data"
make_iso "$seed" "$out/seed.iso"
echo "$out/seed.iso"
