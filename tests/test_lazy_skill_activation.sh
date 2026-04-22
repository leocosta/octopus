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
grep -q "^triggers:" "$SCRIPT_DIR/skills/e2e-testing/SKILL.md" \
  || { echo "FAIL: e2e-testing missing triggers:"; exit 1; }
grep -q 'spec.ts\|cypress\|playwright' "$SCRIPT_DIR/skills/e2e-testing/SKILL.md" \
  || { echo "FAIL: e2e-testing triggers missing expected paths"; exit 1; }
echo "PASS"

echo "Test 7: dotnet has triggers: with paths"
grep -q "^triggers:" "$SCRIPT_DIR/skills/dotnet/SKILL.md" \
  || { echo "FAIL: dotnet missing triggers:"; exit 1; }
grep -q '\.csproj\|\.cs' "$SCRIPT_DIR/skills/dotnet/SKILL.md" \
  || { echo "FAIL: dotnet triggers missing expected paths"; exit 1; }
echo "PASS"

echo "Test 8: cross-stack-contract has triggers: with paths"
grep -q "^triggers:" "$SCRIPT_DIR/skills/cross-stack-contract/SKILL.md" \
  || { echo "FAIL: cross-stack-contract missing triggers:"; exit 1; }
grep -q 'openapi\|contracts' "$SCRIPT_DIR/skills/cross-stack-contract/SKILL.md" \
  || { echo "FAIL: cross-stack-contract triggers missing expected paths"; exit 1; }
echo "PASS"
