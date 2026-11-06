#!/usr/bin/env bash
# Measure what the proxy VM costs the NAS: QEMU CPU and memory against the traffic it forwards.
# Run while streams are playing. Needs passwordless sudo on the NAS.
# Usage: bench/vm-overhead.sh [seconds]
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../vm/vmm.sh
source "$REPO_ROOT/vm/vmm.sh"

dur=${1:-30}

id=$(vm_guest_id)
[[ -n $id ]] || { echo "no VMM guest named $VM_HOSTNAME" >&2; exit 1; }

# Prints: qemu_ticks total_ticks idle_ticks rss_kb clk_tck ncpu
nas_sample() {
  nas_ssh "pid=\$(ps -eo pid,args | awk '\$2 ~ /qemu-system-[a-z0-9_]+\$/ && index(\$0, \"guest=$id\") {print \$1; exit}')
    [ -n \"\$pid\" ] || exit 1
    q=\$(sudo awk '{print \$14 + \$15}' /proc/\$pid/stat)
    rss=\$(sudo awk '/^VmRSS:/ {print \$2}' /proc/\$pid/status)
    awk -v q=\"\$q\" -v rss=\"\$rss\" -v hz=\"\$(getconf CLK_TCK 2>/dev/null || echo 100)\" -v n=\"\$(grep -c ^processor /proc/cpuinfo)\" \
      '/^cpu / {t = 0; for (i = 2; i <= NF; i++) t += \$i; print q, t, \$5 + \$6, rss, hz, n}' /proc/stat"
}

# Prints: tx_bytes haproxy_ticks clk_tck mem_used_mb
vm_sample() {
  vm_ssh "dev=\$(ip route show default | awk '{print \$5; exit}')
    tx=\$(awk -v d=\"\$dev:\" '\$1 == d {print \$10}' /proc/net/dev)
    hp=\$(awk '\$2 == \"(haproxy)\" {s += \$14 + \$15} END {print s + 0}' /proc/[0-9]*/stat 2>/dev/null)
    used=\$(free -m | awk '/^Mem:/ {print \$3}')
    echo \"\$tx \$hp \$(getconf CLK_TCK 2>/dev/null || echo 100) \$used\""
}

read -r q0 t0 i0 _ hz ncpu <<< "$(nas_sample)"
read -r tx0 hp0 vhz _ <<< "$(vm_sample)"
s0=$EPOCHREALTIME
sleep "$dur"
read -r q1 t1 i1 rss _ _ <<< "$(nas_sample)"
read -r tx1 hp1 _ used <<< "$(vm_sample)"
s1=$EPOCHREALTIME

awk -v q0="$q0" -v q1="$q1" -v t0="$t0" -v t1="$t1" -v i0="$i0" -v i1="$i1" -v hz="$hz" -v n="$ncpu" \
  -v tx0="$tx0" -v tx1="$tx1" -v hp0="$hp0" -v hp1="$hp1" -v vhz="$vhz" -v rss="$rss" -v used="$used" \
  -v secs="$(echo "$s1 - $s0" | bc -l)" '
  BEGIN {
    mbps = (tx1 - tx0) * 8 / secs / 1e6
    qemu_core = (q1 - q0) / hz / secs * 100
    nas_busy = (1 - (i1 - i0) / (t1 - t0)) * 100
    hap_core = (hp1 - hp0) / vhz / secs * 100
    printf "interval:            %.0fs\n", secs
    printf "proxied traffic:     %.1f Mbps out of the VM\n", mbps
    printf "QEMU CPU on NAS:     %.1f%% of one core (%.1f%% of all %d cores)\n", qemu_core, qemu_core / n, n
    if (mbps > 0) printf "QEMU CPU per 10 Mbps: %.2f%% of one core\n", qemu_core / mbps * 10
    printf "HAProxy CPU in VM:   %.1f%% of one vCPU\n", hap_core
    printf "NAS CPU busy total:  %.1f%%\n", nas_busy
    printf "QEMU memory on NAS:  %.0f MB resident\n", rss / 1024
    printf "VM memory in use:    %d MB\n", used
  }'
