## Workload Layer Change

### Team / Squad name
<!-- Must match your folder name under workloads/<team>/ -->

### What are you adding or changing?
<!-- Describe the packages, pip installs, or COPY statements. -->

### Why is this needed?
<!-- Brief justification -->

### Checklist

- [ ] My changes are **only** in `workloads/<my-team>/Dockerfile.layer`
- [ ] I have **not** modified `Dockerfile`, `security/`, or `.github/workflows/`
- [ ] I am **not** using forbidden instructions: `FROM`, `USER`, `ENTRYPOINT`, `CMD`, `EXPOSE`
- [ ] I am **not** installing `sudo`
- [ ] All `pip install` commands use `--no-cache-dir`
- [ ] All `apt-get install` commands clean up `rm -rf /var/lib/apt/lists/*` in the same `RUN` block
- [ ] Packages are pinned to specific versions
- [ ] No secrets, credentials, or API keys are embedded
- [ ] I understand that security hardening (sudo disabled, iptables rules) is applied automatically by CI
