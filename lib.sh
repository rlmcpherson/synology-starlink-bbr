# shellcheck shell=bash
# Shared helpers. Source from scripts; do not execute.

if ((BASH_VERSINFO[0] < 5)); then
  echo "bash 5+ required (macOS: brew install bash)" >&2
  exit 1
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export REPO_ROOT

CONFIG=${CONFIG:-$REPO_ROOT/config.env}
if [[ ! -f $CONFIG ]]; then
  echo "missing $CONFIG: copy config.env.example to config.env and edit it" >&2
  exit 1
fi
# shellcheck source=config.env.example
source "$CONFIG"

ssh_opts=(-o ForwardAgent=no -o BatchMode=yes -o LogLevel=ERROR -o ServerAliveInterval=15)

nas_ssh() {
  ssh "${ssh_opts[@]}" -p "$NAS_SSH_PORT" "$NAS_USER@$NAS_HOST" "$@"
}

# With VM_VIA_NAS=1 the VM is reached through nc on the NAS, for when only the NAS is reachable.
# DSM blocks SSH port forwarding for non-root users, so ssh -J does not work.
vm_ssh() {
  local via=()
  if [[ ${VM_VIA_NAS:-0} == 1 ]]; then
    via=(-o "ProxyCommand=ssh ${ssh_opts[*]} -p $NAS_SSH_PORT $NAS_USER@$NAS_HOST $NAS_NC %h %p")
  fi
  ssh "${ssh_opts[@]}" -o StrictHostKeyChecking=accept-new "${via[@]}" "$VM_USER@$VM_IP" "$@"
}
