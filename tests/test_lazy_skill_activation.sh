#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$SCRIPT_DIR/setup.sh"

echo "Test 1: _skill_has_triggers defined in setup.sh"
grep -q "_skill_has_triggers()" "$SETUP" \
  || { echo "FAIL: _skill_has_triggers() missing from setup.sh"; exit 1; }
echo "PASS"

echo "Test 2: _skill_triggers_match defined in setup.sh"
grep -q "_skill_triggers_match()" "$SETUP" \
  || { echo "FAIL: _skill_triggers_match() missing from setup.sh"; exit 1; }
echo "PASS"

echo "Test 3: _skill_triggers_summary defined in setup.sh"
grep -q "_skill_triggers_summary()" "$SETUP" \
  || { echo "FAIL: _skill_triggers_summary() missing from setup.sh"; exit 1; }
echo "PASS"

echo "Test 4: git ls-files cache present in setup.sh"
grep -q "_OCTOPUS_GIT_FILES" "$SETUP" \
  || { echo "FAIL: _OCTOPUS_GIT_FILES cache missing from setup.sh"; exit 1; }
echo "PASS"

echo "Test 5: stub logic present in concatenate_from_manifest"
grep -q "inactive — triggers not matched at setup" "$SETUP" \
  || { echo "FAIL: stub text missing from setup.sh"; exit 1; }
grep -q "Full protocol: read" "$SETUP" \
  || { echo "FAIL: Full protocol stub line missing from setup.sh"; exit 1; }
echo "PASS"

echo "Test 6: glob-to-regex conversion present (DSTAR pattern)"
grep -q "DSTAR" "$SETUP" \
  || { echo "FAIL: glob-to-ERE conversion (DSTAR) missing from setup.sh"; exit 1; }
echo "PASS"

echo "Test 7: skills without triggers: always full — backward compat guard"
grep -q "_skill_has_triggers.*&&.*_skill_triggers_match" "$SETUP" \
  || { echo "FAIL: conditional guard missing — skills without triggers: may be stubbed"; exit 1; }
echo "PASS"

echo "Test 6: e2e-testing has triggers: with paths"
grep -q "^triggers:" "$SCRIPT_DIR/skills/test-e2e/SKILL.md" \
  || { echo "FAIL: e2e-testing missing triggers:"; exit 1; }
grep -q 'spec.ts\|cypress\|playwright' "$SCRIPT_DIR/skills/test-e2e/SKILL.md" \
  || { echo "FAIL: e2e-testing triggers missing expected paths"; exit 1; }
echo "PASS"

echo "Test 7: dotnet has triggers: with paths"
grep -q "^triggers:" "$SCRIPT_DIR/skills/dotnet/SKILL.md" \
  || { echo "FAIL: dotnet missing triggers:"; exit 1; }
grep -q '\.csproj\|\.cs' "$SCRIPT_DIR/skills/dotnet/SKILL.md" \
  || { echo "FAIL: dotnet triggers missing expected paths"; exit 1; }
echo "PASS"

echo "Test 8: review-contracts has triggers: with paths"
grep -q "^triggers:" "$SCRIPT_DIR/skills/review-contracts/SKILL.md" \
  || { echo "FAIL: review-contracts missing triggers:"; exit 1; }
grep -q 'openapi\|contracts' "$SCRIPT_DIR/skills/review-contracts/SKILL.md" \
  || { echo "FAIL: review-contracts triggers missing expected paths"; exit 1; }
echo "PASS"

echo "Test 9: audit-security has triggers: with keywords"
grep -q "^triggers:" "$SCRIPT_DIR/skills/audit-security/SKILL.md" \
  || { echo "FAIL: audit-security missing triggers:"; exit 1; }
grep -q 'auth\|jwt\|secret\|token' "$SCRIPT_DIR/skills/audit-security/SKILL.md" \
  || { echo "FAIL: audit-security triggers missing expected keywords"; exit 1; }
echo "PASS"

echo "Test 10: audit-money has triggers: with keywords"
grep -q "^triggers:" "$SCRIPT_DIR/skills/audit-money/SKILL.md" \
  || { echo "FAIL: audit-money missing triggers:"; exit 1; }
grep -q 'payment\|stripe\|billing\|invoice' "$SCRIPT_DIR/skills/audit-money/SKILL.md" \
  || { echo "FAIL: audit-money triggers missing expected keywords"; exit 1; }
echo "PASS"

echo "Test 11: audit-tenant has triggers: with keywords"
grep -q "^triggers:" "$SCRIPT_DIR/skills/audit-tenant/SKILL.md" \
  || { echo "FAIL: audit-tenant missing triggers:"; exit 1; }
grep -q 'tenant\|org\|workspace' "$SCRIPT_DIR/skills/audit-tenant/SKILL.md" \
  || { echo "FAIL: audit-tenant triggers missing expected keywords"; exit 1; }
echo "PASS"

echo "Test 12: plan-backlog has triggers: with paths and keywords"
grep -q "^triggers:" "$SCRIPT_DIR/skills/plan-backlog/SKILL.md" \
  || { echo "FAIL: plan-backlog missing triggers:"; exit 1; }
grep -q 'plans/\|roadmap' "$SCRIPT_DIR/skills/plan-backlog/SKILL.md" \
  || { echo "FAIL: plan-backlog triggers missing expected paths"; exit 1; }
grep -q 'plan\|backlog\|roadmap' "$SCRIPT_DIR/skills/plan-backlog/SKILL.md" \
  || { echo "FAIL: plan-backlog triggers missing expected keywords"; exit 1; }
echo "PASS"

echo "Test 13: launch-release has triggers: with paths and keywords"
grep -q "^triggers:" "$SCRIPT_DIR/skills/launch-release/SKILL.md" \
  || { echo "FAIL: launch-release missing triggers:"; exit 1; }
grep -q 'CHANGELOG\|releases/' "$SCRIPT_DIR/skills/launch-release/SKILL.md" \
  || { echo "FAIL: launch-release triggers missing expected paths"; exit 1; }
grep -q 'release\|changelog\|announce' "$SCRIPT_DIR/skills/launch-release/SKILL.md" \
  || { echo "FAIL: launch-release triggers missing expected keywords"; exit 1; }
echo "PASS"
