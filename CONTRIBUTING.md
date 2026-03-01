# Contributing a Workload Layer

This repo builds a shared, hardened Docker image used across all workload teams.
Each team has **its own isolated folder** and never touches the platform base or another team's files.

---

## How to onboard your team

### 1. Create your team folder

```
workloads/
└── <your-team-name>/
    └── Dockerfile.layer
```

```bash
mkdir -p workloads/my-team
touch workloads/my-team/Dockerfile.layer
```

### 2. Write your `Dockerfile.layer`

Your layer is a partial Dockerfile — a list of `RUN`, `COPY`, `ENV`, `ARG`, and `WORKDIR`
instructions that get stitched on top of the platform base image (`python:3.12-slim`).

**Permitted instructions:** `RUN`, `COPY`, `ENV`, `ARG`, `WORKDIR`, `LABEL`

**Forbidden instructions:** `FROM`, `USER`, `ENTRYPOINT`, `CMD`, `EXPOSE`

#### Example

```dockerfile
# workloads/my-team/Dockerfile.layer

RUN pip install --no-cache-dir \
    requests==2.31.0 \
    fastapi==0.110.0

ENV MY_TEAM_ENV=production
WORKDIR /opt/my-app
```

### 3. Rules to follow

| Rule | Why |
|---|---|
| Only use permitted instructions | `FROM`, `USER`, `ENTRYPOINT` etc. are platform-controlled |
| Never install `sudo` | `sudo` is disabled by the hardening step — it won't work at runtime |
| Always use `--no-cache-dir` on `pip install` | Keeps image size small |
| Always `rm -rf /var/lib/apt/lists/*` after `apt-get install` | Keeps image size small |
| Pin package versions | Reproducible, auditable builds |
| No secrets in the layer file | Use runtime env vars or a secrets manager instead |

### 4. Open a PR

- Your PR should **only** touch files inside `workloads/<your-team>/`
- One team per PR — mixed-team PRs will be rejected by CI
- CI will validate your layer, lint it, and smoke-build the full image
- A bot will comment the result on your PR

### 5. What happens on merge

The platform CI will:
1. Stitch all team layers (alphabetical order) on top of the base image
2. Apply security hardening automatically:
   - `sudo` disabled
   - `su` restricted
   - Sensitive binaries (`curl`, `wget`, `nc`) restricted to root
   - Non-root runtime user `appuser (uid=10001)` created
   - IPTables entrypoint injected (default-DROP, outbound HTTPS+DNS only)
3. Run a Trivy vulnerability scan
4. Push a dedicated hardened image for your team to GHCR with `latest`, date, and SHA tags

---

## Repo structure

```
├── Dockerfile                          ← Platform base (do not modify)
├── CONTRIBUTING.md                     ← This file
├── security/
│   ├── harden.sh                       ← Stitches layers + appends hardening
│   ├── validate_layer.py               ← Validates Dockerfile.layer files
│   ├── iptables-rules.sh               ← Applied at container startup
│   └── entrypoint.sh                   ← Applies iptables then drops to appuser
├── workloads/
│   ├── payments-team/
│   │   └── Dockerfile.layer
│   ├── data-science-team/
│   │   └── Dockerfile.layer
│   └── <your-team>/
│       └── Dockerfile.layer            ← Your file goes here
└── .github/
    ├── PULL_REQUEST_TEMPLATE.md
    └── workflows/
        └── docker-platform.yml
```

---

## Questions?

Reach out to the Platform Team via Teams.
