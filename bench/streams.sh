#!/usr/bin/env bash
# Show live client connections the VM is proxying to Plex.
# Usage: bench/streams.sh [port]
set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

port=${1:-32400}
vm_ssh "ss -tinH state established '( sport = :$port )'" | "$REPO_ROOT/bench/ss-summary.sh"
