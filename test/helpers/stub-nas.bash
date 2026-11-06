# Stubs ssh (the NAS) and curl for scripts that drive the NAS remotely.
# Every remote command is appended to $CALLS. Responses are controlled by STUB_* variables.

setup_stub_nas() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  FIX=$BATS_TEST_DIRNAME/fixtures
  export CONFIG=$FIX/config.env
  BIN=$(mktemp -d)
  CALLS=$BIN/calls
  : > "$CALLS"
  export FIX CALLS

  cat > "$BIN/ssh" <<'EOF'
#!/usr/bin/env bash
cmd=${!#}
printf '%s\n' "$cmd" >> "$CALLS"
case $cmd in
  *qemu-system*)
    # NAS sample: qemu_ticks total_ticks idle_ticks rss_kb clk_tck ncpu
    count=$(dirname "$CALLS")/nas-count
    n=$(( $(cat "$count" 2>/dev/null || echo 0) + 1 ))
    echo "$n" > "$count"
    echo "$((1000 + n * 50)) $((50000 + n * 200)) $((40000 + n * 100)) 1349632 100 2"
    ;;
  */proc/net/dev*)
    # VM sample: tx_bytes haproxy_ticks clk_tck mem_used_mb
    count=$(dirname "$CALLS")/vm-count
    n=$(( $(cat "$count" 2>/dev/null || echo 0) + 1 ))
    echo "$n" > "$count"
    echo "$((n * 5000000)) $((500 + n * 3)) 100 280"
    ;;
  *synowebapi*) cat "${STUB_GUESTS:-$FIX/vmm-guest-list.txt}" ;;
  *domblklist*) cat "$FIX/domblklist.txt" ;;
  *"stat -c %s"*) echo "${STUB_IMG_SIZE:-3221225472}" ;;
  *blockdev*) echo "${STUB_DEV_SIZE:-10737418240}" ;;
  *"cmp -s -n"*/dev/zero*) exit "${STUB_BLANK_EXIT:-0}" ;;
  *"cmp -s -n"*) exit "${STUB_VERIFY_EXIT:-0}" ;;
  *"ss -tinH"*)
    # Busiest connection grows 1 MB per call.
    count=$(dirname "$CALLS")/ss-count
    n=$(( $(cat "$count" 2>/dev/null || echo 0) + 1 ))
    echo "$n" > "$count"
    [ -n "${STUB_SS_EMPTY:-}" ] && exit 0
    printf '0 0 192.168.1.254:32400 203.0.113.7:27422\n\t bbr bytes_sent:%d\n' $((n * 1000000))
    printf '0 0 192.168.1.254:32400 203.0.113.7:31943\n\t bbr bytes_sent:900\n'
    ;;
  *"if [ -f"*) echo "${STUB_SHA_EXISTING:-}" ;;
  *sha512sum*) echo "${STUB_SHA_PART:-}" ;;
esac
EOF

  cat > "$BIN/curl" <<'EOF'
#!/usr/bin/env bash
cat "${STUB_SUMS:-$FIX/SHA512SUMS}"
EOF

  chmod +x "$BIN/ssh" "$BIN/curl"
  PATH="$BIN:$PATH"
}

teardown_stub_nas() {
  rm -rf "$BIN"
}

called() {
  grep -qF -- "$1" "$CALLS"
}
