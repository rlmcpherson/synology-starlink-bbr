#!/usr/bin/env bash
# Render the proxy config, push it to the VM, validate it, and apply.
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

cfg=$(mktemp)
trap 'rm -f "$cfg"' EXIT
"$REPO_ROOT/proxy/render-haproxy.sh" > "$cfg"

vm_ssh 'mkdir -p /tmp/proxy'
vm_ssh 'cat > /tmp/proxy/haproxy.cfg' < "$cfg"
vm_ssh 'cat > /tmp/proxy/99-bbr.conf' < "$REPO_ROOT/proxy/99-bbr.conf"

vm_ssh 'sudo bash -s' <<'EOF'
set -euo pipefail
haproxy -c -q -f /tmp/proxy/haproxy.cfg
install -m 644 /tmp/proxy/99-bbr.conf /etc/sysctl.d/99-bbr.conf
sysctl -q --system
install -m 644 /tmp/proxy/haproxy.cfg /etc/haproxy/haproxy.cfg
systemctl reload-or-restart haproxy
echo "congestion control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "haproxy: $(systemctl is-active haproxy)"
EOF
