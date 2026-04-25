#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD_FILE="$SCRIPT_DIR/commands/doc-plan.md"
DESIGN_CMD_FILE="$SCRIPT_DIR/commands/doc-design.md"
FIXTURE="$SCRIPT_DIR/skills/doc-plan/templates/plan-skeleton.md"
BUNDLE_FILE="$SCRIPT_DIR/bundles/documentation.yml"
WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"

echo "Test 1: commands/doc-plan.md exists with valid frontmatter"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE not found"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: doc-plan$" \
  || { echo "FAIL: frontmatter 'name: doc-plan' missing"; exit 1; }
head -n 10 "$CMD_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description:' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: plan-skeleton fixture exists"
[[ -f "$FIXTURE" ]] || { echo "FAIL: $FIXTURE not found"; exit 1; }
grep -q "REQUIRED SUB-SKILL" "$FIXTURE" \
  || { echo "FAIL: skeleton missing REQUIRED SUB-SKILL line"; exit 1; }
grep -q "## File Structure" "$FIXTURE" \
  || { echo "FAIL: skeleton missing File Structure section"; exit 1; }
grep -q "## Task 1" "$FIXTURE" \
  || { echo "FAIL: skeleton missing Task skeleton"; exit 1; }
echo "PASS: plan-skeleton fixture present"

echo "Test 3: command documents the HARD-GATE"
grep -q "HARD-GATE:" "$CMD_FILE" \
  || { echo "FAIL: 'HARD-GATE:' anchor missing"; exit 1; }
grep -qE "do not write (production )?code|never writes (production )?code|does not write (production )?code" "$CMD_FILE" \
  || { echo "FAIL: explicit 'do not write code' prohibition missing"; exit 1; }
echo "PASS: HARD-GATE documented"

echo "Test 4: command documents all seven steps"
for n in 1 2 3 4 5 6 7; do
  grep -qE "^##+ .*Step $n\b" "$CMD_FILE" \
    || { echo "FAIL: Step $n header missing"; exit 1; }
done
echo "PASS: all seven steps documented"

echo "Test 5: command documents the adaptive decomposition keywords"
for kw in "too big" "too small" "break into" "fold into"; do
  grep -q "$kw" "$CMD_FILE" \
    || { echo "FAIL: adaptive keyword '$kw' missing"; exit 1; }
done
echo "PASS: adaptive decomposition documented"

echo "Test 6: command references the output path docs/plans/"
grep -q "docs/plans/" "$CMD_FILE" \
  || { echo "FAIL: docs/plans/ output path missing"; exit 1; }
echo "PASS: output path documented"

echo "Test 7: command handles docs-only branch auto-create"
grep -q "docs/<slug>-plan" "$CMD_FILE" \
  || { echo "FAIL: docs/<slug>-plan branch reference missing"; exit 1; }
grep -q "Never commit the plan directly onto" "$CMD_FILE" \
  || { echo "FAIL: forbid-direct-commit-to-main statement missing"; exit 1; }
echo "PASS: docs-only branch flow documented"

echo "Test 8: bundle documentation includes doc-plan"
grep -qE "^\s*-\s*doc-plan\s*$" "$BUNDLE_FILE" \
  || { echo "FAIL: doc-plan not listed in documentation bundle"; exit 1; }
echo "PASS: bundle registration present"

echo "Test 9: wizard includes doc-plan"
grep -E "^[[:space:]]*local items=\(.*doc-plan.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: doc-plan not in wizard items array"; exit 1; }
grep -q 'doc-plan|' "$WIZARD" \
  || { echo "FAIL: doc-plan hint missing"; exit 1; }
echo "PASS: wizard registration present"

echo "Test 10: doc-design chains into doc-plan"
grep -q "/octopus:doc-plan" "$DESIGN_CMD_FILE" \
  || { echo "FAIL: doc-design does not reference /octopus:doc-plan"; exit 1; }
grep -q "available once RM-036 ships" "$DESIGN_CMD_FILE" \
  && { echo "FAIL: doc-design still gates doc-plan behind 'available once RM-036 ships'"; exit 1; }
echo "PASS: doc-design chains into doc-plan"
