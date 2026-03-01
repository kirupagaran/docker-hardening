#!/usr/bin/env bash
# =============================================================
# harden.sh
#
# Builds a hardened Dockerfile for a SINGLE workload team by:
#   1. Copying the platform base Dockerfile
#   2. Appending that team's Dockerfile.layer
#   3. Appending the security hardening block
#
# Usage:
#   bash security/harden.sh <team-name> [workloads-dir] [output-dir]
#
# Example:
#   bash security/harden.sh payments-team
#   bash security/harden.sh payments-team workloads/ build/
#
# Output:
#   <output-dir>/<team-name>/Dockerfile.hardened
# =============================================================
set -euo pipefail

TEAM="${1:?Usage: harden.sh <team-name> [workloads-dir] [output-dir]}"
WORKLOADS_DIR="${2:-workloads}"
OUTPUT_DIR="${3:-build}"

LAYER_FILE="$WORKLOADS_DIR/$TEAM/Dockerfile.layer"
OUTPUT_FILE="$OUTPUT_DIR/$TEAM/Dockerfile.hardened"

# ── Validate inputs ───────────────────────────────────────────
if [ ! -f "Dockerfile" ]; then
  echo "❌ Base Dockerfile not found in current directory."
  exit 1
fi

if [ ! -f "$LAYER_FILE" ]; then
  echo "❌ Layer file not found: $LAYER_FILE"
  exit 1
fi

mkdir -p "$OUTPUT_DIR/$TEAM"

echo "[+] Building hardened Dockerfile for team: $TEAM"
echo "    Base:   Dockerfile"
echo "    Layer:  $LAYER_FILE"
echo "    Output: $OUTPUT_FILE"
echo ""

# ── Step 1: Start from the platform base ─────────────────────
cp Dockerfile "$OUTPUT_FILE"

# ── Step 2: Append the team's workload layer ─────────────────
{
  printf '\n'
  printf '# ── Workload layer: %s ──────────────────────────────\n' "$TEAM"
  cat "$LAYER_FILE"
  printf '\n'
} >> "$OUTPUT_FILE"

echo "[+] Workload layer appended"

# ── Step 3: Append security hardening ────────────────────────
echo "[+] Appending security hardening"

cat >> "$OUTPUT_FILE" << 'HARDENING'

# ==============================================================
# SECURITY HARDENING — Injected by Platform CI. Do not modify.
# ==============================================================

# ── 1. Disable sudo ───────────────────────────────────────────
RUN if command -v sudo > /dev/null 2>&1; then \
        dpkg -l sudo 2>/dev/null | grep -q '^ii' \
            && apt-get remove -y --purge sudo \
            || chmod 000 /usr/bin/sudo; \
    fi \
 && ln -sf /bin/false /usr/local/bin/sudo

# ── 2. Restrict su ────────────────────────────────────────────
RUN chmod 750 /bin/su && chown root:root /bin/su

# ── 3. Restrict sensitive network binaries ────────────────────
RUN chmod o-x /usr/bin/wget  2>/dev/null || true \
 && chmod o-x /usr/bin/curl  2>/dev/null || true \
 && chmod o-x /usr/bin/nc    2>/dev/null || true \
 && chmod o-x /usr/bin/ncat  2>/dev/null || true

# ── 4. Create a non-root runtime user ────────────────────────
RUN groupadd --gid 10001 appgroup \
 && useradd  --uid 10001 --gid appgroup \
             --shell /bin/sh \
             --no-create-home \
             appuser

# ── 5. Install iptables entrypoint scripts ────────────────────
# iptables rules cannot persist in a static image layer because
# the kernel network stack is unavailable at build time.
# Rules are applied at container startup via the entrypoint.
# Requires: --cap-add NET_ADMIN on docker run / pod securityContext.
COPY security/iptables-rules.sh /usr/local/bin/iptables-rules.sh
COPY security/entrypoint.sh     /usr/local/bin/entrypoint.sh
RUN  chmod 500 /usr/local/bin/iptables-rules.sh \
  && chmod 500 /usr/local/bin/entrypoint.sh \
  && chown root:root /usr/local/bin/iptables-rules.sh \
  && chown root:root /usr/local/bin/entrypoint.sh

# ── 6. Drop to non-root for runtime ──────────────────────────
USER appuser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# ==============================================================
HARDENING

echo "[+] Done — $OUTPUT_FILE"
echo ""
echo "=== Final Dockerfile ==="
cat "$OUTPUT_FILE"
