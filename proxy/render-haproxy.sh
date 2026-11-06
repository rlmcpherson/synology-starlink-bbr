#!/usr/bin/env bash
# Print haproxy.cfg: the base config plus one listen block per entry in SERVICES.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

valid_port() {
  [[ $1 =~ ^[0-9]+$ ]] && (($1 >= 1 && $1 <= 65535))
}

[[ -n ${SERVICES// /} ]] || { echo "SERVICES is empty" >&2; exit 1; }

cat "$REPO_ROOT/proxy/haproxy-base.cfg"
declare -A ports names
for svc in $SERVICES; do
  IFS=: read -r name port target extra <<< "$svc"
  target=${target:-$port}
  if [[ ! $name =~ ^[A-Za-z0-9_-]+$ ]] || ! valid_port "$port" || ! valid_port "$target" || [[ -n $extra ]]; then
    echo "bad SERVICES entry '$svc': want name:port or name:listen_port:nas_port" >&2
    exit 1
  fi
  if [[ -n ${ports[$port]:-} || -n ${names[$name]:-} ]]; then
    echo "duplicate name or port in SERVICES entry '$svc'" >&2
    exit 1
  fi
  ports[$port]=1
  names[$name]=1
  printf '\nlisten %s\n    bind :%s\n    server nas %s:%s\n' "$name" "$port" "$NAS_LAN_IP" "$target"
done
