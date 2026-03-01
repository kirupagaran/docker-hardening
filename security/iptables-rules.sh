#!/usr/bin/env bash
# =============================================================
# iptables-rules.sh — Applied at container startup.
# Requires: --cap-add NET_ADMIN on `docker run`.
# Customise the ALLOW_* variables via environment variables.
# =============================================================
set -euo pipefail

echo "[security] Applying iptables hardening rules..."

# ── Flush existing rules ──────────────────────────────────────
iptables  -F
iptables  -X
iptables  -Z
ip6tables -F 2>/dev/null || true
ip6tables -X 2>/dev/null || true

# ── Default DROP policy ───────────────────────────────────────
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP

# Block all IPv6 by default (least-privilege)
ip6tables -P INPUT   DROP 2>/dev/null || true
ip6tables -P OUTPUT  DROP 2>/dev/null || true
ip6tables -P FORWARD DROP 2>/dev/null || true

# ── Allow loopback ───────────────────────────────────────────
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ── Allow established / related connections ───────────────────
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ── Outbound: DNS (required for most workloads) ───────────────
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# ── Outbound: HTTPS only (no plain HTTP by default) ──────────
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# ── Optional: allow plain HTTP (set ALLOW_HTTP=1) ────────────
if [[ "${ALLOW_HTTP:-0}" == "1" ]]; then
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
fi

# ── Optional: allow custom outbound port range ────────────────
# Set ALLOW_OUTBOUND_PORTS="8080 9090" to open extra ports
for port in ${ALLOW_OUTBOUND_PORTS:-}; do
    iptables -A OUTPUT -p tcp --dport "$port" -j ACCEPT
done

# ── Inbound: allow app port (default 8080, override via APP_PORT) ──
APP_PORT="${APP_PORT:-8080}"
iptables -A INPUT -p tcp --dport "$APP_PORT" -j ACCEPT

# ── Block private RFC-1918 ranges on output (prevent SSRF/lateral) ──
if [[ "${BLOCK_RFC1918_EGRESS:-1}" == "1" ]]; then
    iptables -A OUTPUT -d 10.0.0.0/8     -j DROP
    iptables -A OUTPUT -d 172.16.0.0/12  -j DROP
    iptables -A OUTPUT -d 192.168.0.0/16 -j DROP
    iptables -A OUTPUT -d 169.254.0.0/16 -j DROP  # block IMDS by default
fi

# ── Log and drop everything else ─────────────────────────────
iptables -A INPUT  -j LOG --log-prefix "[IPT-DROP-IN]  " --log-level 4
iptables -A OUTPUT -j LOG --log-prefix "[IPT-DROP-OUT] " --log-level 4
iptables -A INPUT  -j DROP
iptables -A OUTPUT -j DROP

echo "[security] iptables rules applied."
iptables -L -n -v
