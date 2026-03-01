#!/usr/bin/env python3
"""
validate_layer.py
=================
Validates a workload Dockerfile.layer file.

Checks:
  1. Only permitted Dockerfile instructions are used.
  2. Forbidden instructions (FROM, USER, ENTRYPOINT, CMD, EXPOSE) are absent.
  3. sudo is not installed or enabled.
  4. pip installs use --no-cache-dir.
  5. apt-get installs clean up the cache in the same RUN block.

Usage:
    python3 validate_layer.py workloads/payments-team/Dockerfile.layer
    python3 validate_layer.py workloads/          # validate all layers
"""

import re
import sys
from pathlib import Path

# ── Configuration ─────────────────────────────────────────────────────────────

FORBIDDEN_INSTRUCTIONS = {"FROM", "USER", "ENTRYPOINT", "CMD", "EXPOSE"}
PERMITTED_INSTRUCTIONS = {"RUN", "COPY", "ENV", "ARG", "WORKDIR", "LABEL", "#"}

SUDO_PATTERNS = [
    r"\bsudo\b",
    r"apt-get install.*\bsudo\b",
    r"apk add.*\bsudo\b",
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def parse_instructions(content: str) -> list[tuple[int, str, str]]:
    """Return list of (line_number, instruction, rest_of_line)."""
    results = []
    for i, raw in enumerate(content.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            results.append((i, "#", line))
            continue
        parts = line.split(None, 1)
        instruction = parts[0].upper()
        rest = parts[1] if len(parts) > 1 else ""
        results.append((i, instruction, rest))
    return results


def validate_layer(path: Path) -> list[str]:
    """Return a list of violation strings. Empty list = passed."""
    violations = []
    content = path.read_text()
    instructions = parse_instructions(content)

    # ── 1. Forbidden instructions ──────────────────────────────────────────
    for lineno, instr, rest in instructions:
        if instr in FORBIDDEN_INSTRUCTIONS:
            violations.append(
                f"  Line {lineno}: Forbidden instruction '{instr}' — "
                f"not permitted in a workload layer."
            )

    # ── 2. Unknown instructions ────────────────────────────────────────────
    for lineno, instr, rest in instructions:
        if instr not in PERMITTED_INSTRUCTIONS and instr not in FORBIDDEN_INSTRUCTIONS:
            violations.append(
                f"  Line {lineno}: Unknown or unexpected instruction '{instr}'."
            )

    # ── 3. sudo usage ──────────────────────────────────────────────────────
    for lineno, instr, rest in instructions:
        for pattern in SUDO_PATTERNS:
            if re.search(pattern, rest, re.IGNORECASE):
                violations.append(
                    f"  Line {lineno}: sudo detected ('{pattern}') — "
                    f"sudo is disabled in hardened images."
                )
                break

    # ── 4. pip install without --no-cache-dir ─────────────────────────────
    for lineno, instr, rest in instructions:
        if instr == "RUN" and "pip install" in rest:
            if "--no-cache-dir" not in rest:
                violations.append(
                    f"  Line {lineno}: 'pip install' missing --no-cache-dir flag — "
                    f"add it to keep the image lean."
                )

    # ── 5. apt-get install without cache cleanup ──────────────────────────
    for lineno, instr, rest in instructions:
        if instr == "RUN" and "apt-get install" in rest:
            if "rm -rf /var/lib/apt/lists" not in rest:
                violations.append(
                    f"  Line {lineno}: 'apt-get install' without "
                    f"'rm -rf /var/lib/apt/lists/*' in the same RUN block — "
                    f"clean up the cache to keep the image lean."
                )

    return violations


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: validate_layer.py <path-to-Dockerfile.layer | workloads-dir>")
        sys.exit(1)

    target = Path(sys.argv[1])
    files: list[Path] = []

    if target.is_dir():
        files = sorted(target.rglob("Dockerfile.layer"))
        if not files:
            print(f"No Dockerfile.layer files found under {target}")
            sys.exit(0)
    elif target.is_file():
        files = [target]
    else:
        print(f"Path not found: {target}")
        sys.exit(1)

    total_violations = 0

    for layer_path in files:
        team = layer_path.parent.name
        violations = validate_layer(layer_path)

        if violations:
            print(f"❌  {team} ({layer_path})")
            for v in violations:
                print(v)
            print()
            total_violations += len(violations)
        else:
            print(f"✅  {team} ({layer_path}) — OK")

    print()
    if total_violations:
        print(f"Validation FAILED with {total_violations} violation(s).")
        sys.exit(1)
    else:
        print("All layers passed validation.")
        sys.exit(0)


if __name__ == "__main__":
    main()
