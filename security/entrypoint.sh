#!/usr/bin/env bash
# =============================================================
# entrypoint.sh — Container entrypoint.
# 1. Applies iptables rules (as root via --cap-add NET_ADMIN)
# 2. Drops privileges and execs the workload command
# =============================================================
set -euo pipefail

# Apply iptables hardening (requires NET_ADMIN cap)
if [[ "$(id -u)" == "0" ]]; then
    /usr/local/bin/iptables-rules.sh
    # Drop to non-root user for the actual workload
    exec gosu appuser "$@"
else
    # Already non-root (e.g. in orchestrators that set runAsNonRoot)
    echo "[warn] Running as non-root; iptables hardening skipped (no CAP_NET_ADMIN)."
    exec "$@"
fi
