# ============================================================
# BASE IMAGE - Owned and maintained by the Platform Team.
#
# Do NOT modify this file to add workload packages.
# Each workload team has its own folder: workloads/<team>/
# See CONTRIBUTING.md for onboarding instructions.
# Security hardening is applied automatically by CI/CD.
# ============================================================

FROM python:3.12-slim

ARG DEBIAN_FRONTEND=noninteractive

# ── Platform-managed base packages ─────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    iptables \
    iproute2 \
 && rm -rf /var/lib/apt/lists/*

# CI stitches each team's Dockerfile.layer on top of this base,
# then appends security hardening as the final layer.
# Do NOT add anything below this line.
