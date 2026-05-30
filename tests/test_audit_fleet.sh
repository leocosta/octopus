#!/usr/bin/env bash
# tests/test_audit_fleet.sh
# Structural tests for the audit-fleet skill (RM-094).
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/audit-fleet/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- the skill ----------------------------------------------------------
check "SKILL.md exists" test -f "$SKILL"
check "declares name audit-fleet" grep -q "name: audit-fleet" "$SKILL"
check "has trigger keywords" grep -qiE "fleet audit|drift across|across repos|which repos|adoption" "$SKILL"

# --- fleet resolution (aligned to RM-095) -------------------------------
check "resolves the fleet from fleet.yml" grep -q "fleet.yml" "$SKILL"
check "declares a resolution precedence" grep -qiE "precedence|in order|primary|fall ?back|falls back" "$SKILL"
check "shares the repo list with fleet-bootstrap" grep -qi "fleet-bootstrap" "$SKILL"

# --- target composition + actual-vs-target ------------------------------
check "computes target = baseline + profile + tier" grep -qiE "baseline.*profile.*tier|baseline ∪ profile|target" "$SKILL"
check "measures drift against the declared target" grep -qiE "vs.*target|against.*target|actual.*target|target.*actual" "$SKILL"
check "checks adoption tier (actual vs declared)" grep -qi "tier" "$SKILL"
check "checks stack profile / bundles" grep -qiE "profile|bundles" "$SKILL"
check "checks Octopus version" grep -qiE "version" "$SKILL"
check "checks CONTEXT.md / ADR adoption" grep -qE "CONTEXT.md" "$SKILL" && grep -qiE "ADR" "$SKILL"

# --- report shape -------------------------------------------------------
check "per-repo table" grep -qiE "per-repo table|per repo|table" "$SKILL"
check "drift-hotspots rollup" grep -qiE "hotspot|rollup|most inconsistent|biggest.*gap" "$SKILL"

# --- signal-only + remediation handoff ----------------------------------
check "is signal-only / read-only, never mutates" grep -qiE "signal-only|read-only|never mutate|does not mutate|reports.*never" "$SKILL"
check "points to fleet-bootstrap for remediation" grep -qiE "remediat|fleet-bootstrap|--from-audit" "$SKILL"
check "feeds --from-audit" grep -q -- "--from-audit" "$SKILL"

# --- reuse + execution model --------------------------------------------
check "reuses audit-config rather than reimplement" grep -qi "audit-config" "$SKILL"
check "v1 operates on local checkouts" grep -qiE "local checkout|local checkouts|locally|checked-out" "$SKILL"

# --- bundle registration ------------------------------------------------
check "registered in quality bundle (interim)" grep -q "audit-fleet" "$OCTOPUS_DIR/bundles/quality.yml"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
