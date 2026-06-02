#!/usr/bin/env bash
# Guard: Octopus's own internal development markers must not leak into the
# surfaces that get delivered into a consumer's repo by `octopus setup`
# (skills, commands, templates).
#
# Scope is deliberately limited to classes with ZERO false-positive risk:
#   - `Cluster N`  — always an Octopus-internal roadmap grouping.
#   - links into Octopus's own design docs on GitHub (docs/{adr,specs,rfcs,roadmap}).
#   - `ADR-NNN` citations in skills/ and commands/ — concrete internal ADR ids.
#
# `RM-NNN` is intentionally NOT guarded: it is the roadmap-item ID convention
# the user inherits (e.g. `launch-feature RM-008`, `feat/RM-042-…` branch names),
# so a blanket block would false-positive. `templates/` is excluded from the
# ADR-NNN check because the doc templates legitimately ship example placeholders
# (e.g. `templates/spec.md` → `Related ADRs: [ADR-001, ADR-005]`).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
fail=0

report() {  # $1 = human label, $2 = matches
  if [[ -n "$2" ]]; then
    echo "FAIL: $1"
    printf '%s\n' "$2" | sed 's/^/    /'
    fail=1
  fi
}

cluster="$(grep -rnE 'Cluster [0-9]+' skills/ commands/ templates/ 2>/dev/null || true)"
report "'Cluster N' (Octopus-internal roadmap grouping) in delivered files" "$cluster"

links="$(grep -rnE 'github\.com/leocosta/octopus/blob/[^)]*/docs/(adr|specs|rfcs|roadmap)' skills/ commands/ templates/ 2>/dev/null || true)"
report "link into Octopus's own internal design docs" "$links"

adr="$(grep -rnE '\bADR-[0-9]+|\badr-0[0-9]' skills/ commands/ 2>/dev/null || true)"
report "internal 'ADR-NNN' citation in skills/ or commands/" "$adr"

if [[ "$fail" -eq 0 ]]; then
  echo "PASS: no Octopus-internal refs leak into delivered skills/commands/templates"
fi
exit "$fail"
