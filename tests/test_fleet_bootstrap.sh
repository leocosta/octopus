#!/usr/bin/env bash
# tests/test_fleet_bootstrap.sh
# Structural tests for the fleet-bootstrap skill (RM-095).
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/fleet-bootstrap/SKILL.md"
CMD="$OCTOPUS_DIR/commands/fleet-bootstrap.md"
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
check "declares name fleet-bootstrap" grep -q "name: fleet-bootstrap" "$SKILL"

# --- source of truth (D3) -----------------------------------------------
check "reads fleet.yml" grep -q "fleet.yml" "$SKILL"
check "fleet.yml lives in the workspace repo" grep -qiE "workspace" "$SKILL"
check "fleet.yml carries baseline/profiles/tiers/repos" grep -qi "baseline" "$SKILL" && grep -qi "profiles" "$SKILL" && grep -qi "tiers" "$SKILL"

# --- layered standard (D1) ----------------------------------------------
check "composes baseline + profile + tier" grep -qiE "baseline.*profile.*tier|baseline ∪ profile|baseline \+ profile" "$SKILL"
check "stack auto-detection" grep -qiE "detect|auto-detect|\.csproj|package.json|pyproject" "$SKILL"
check "profile override in the fleet list" grep -qiE "override|pin|declared profile" "$SKILL"

# --- adoption tiers (D2) ------------------------------------------------
check "declares tiers T0/T1/T2" grep -q "T0" "$SKILL" && grep -q "T1" "$SKILL" && grep -q "T2" "$SKILL"
check "tier maps to hooks/precommit/qualityWorkflow" grep -qi "hooks" "$SKILL" && grep -qi "precommit" "$SKILL" && grep -qi "qualityWorkflow" "$SKILL"
check "T1 gates enforce-ide, T2 gates enforce-precommit" grep -qi "enforce-ide" "$SKILL" && grep -qi "enforce-precommit" "$SKILL"
check "legacy starts low and ratchets up" grep -qiE "legacy|ratchet|escalat" "$SKILL"

# --- seeding delegated to setup -----------------------------------------
check "delegates seeding to octopus setup" grep -qiE "octopus setup|runs setup|run .octopus setup" "$SKILL"
check "writes only the .octopus.yml directly" grep -qiE "only.*\.octopus\.yml|writes.*\.octopus\.yml" "$SKILL"

# --- merge policy (D4) --------------------------------------------------
check "per-key merge converges baseline+tier" grep -qiE "per-key|per key|converge" "$SKILL"
check "keeps profile-justified local additions" grep -qiE "justified|matches the profile|keep" "$SKILL"
check "flags arbitrary divergence, never silent removal" grep -qiE "flag|conflict|never.*silent|not.*silent" "$SKILL"
check "tier de-escalation is flagged" grep -qiE "de-escalat|downgrade|reduce.*enforcement" "$SKILL"
check "local rule overrides survive" grep -qiE "\.local\.md|project override|survive" "$SKILL"

# --- safety / execution (D6) --------------------------------------------
check "dry-run is the default" grep -qiE "dry-run.*default|default.*dry-run|preview.*default" "$SKILL"
check "declares --apply" grep -q -- "--apply" "$SKILL"
check "declares --yes for trusted batch" grep -q -- "--yes" "$SKILL"
check "declares --pr (guarded, never push main)" grep -q -- "--pr" "$SKILL" && grep -qiE "never.*push|not.*push.*main|guarded" "$SKILL"
check "declares --from-audit (audit-fleet scoping)" grep -q -- "--from-audit" "$SKILL"
check "shares the repo-list resolver with audit-fleet" grep -qi "audit-fleet" "$SKILL"
check "v1 operates on local checkouts" grep -qiE "local checkout|local checkouts|locally" "$SKILL"

# --- the command --------------------------------------------------------
check "command file exists" test -f "$CMD"
check "command declares fleet-bootstrap" grep -qi "fleet-bootstrap" "$CMD"

# --- bundle registration ------------------------------------------------
check "registered in tech-lead bundle" grep -q "fleet-bootstrap" "$OCTOPUS_DIR/bundles/tech-lead.yml"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
