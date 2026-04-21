#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/compress-skill/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: compress-skill$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation with required flags"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:compress-skill" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--apply" "--target" "--max-loss" "--heuristics-only"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents the two-pass protocol"
grep -q "^## Step 1 — Deterministic cleanup$" "$SKILL_FILE" \
  || { echo "FAIL: Step 1 section missing"; exit 1; }
grep -q "^## Step 2 — LLM rewrite" "$SKILL_FILE" \
  || { echo "FAIL: Step 2 section missing"; exit 1; }
echo "PASS: two-pass protocol documented"

echo "Test 4: SKILL.md documents invariants"
grep -q "^## Invariants" "$SKILL_FILE" \
  || { echo "FAIL: invariants section missing"; exit 1; }
for inv in "[Ff]rontmatter" "[Aa]nchor" "heading" "code block"; do
  grep -qE "$inv" "$SKILL_FILE" \
    || { echo "FAIL: invariant '$inv' not documented"; exit 1; }
done
echo "PASS: invariants documented"

echo "Test 5: LLM prompt template exists"
TEMPLATES="$SCRIPT_DIR/skills/compress-skill/templates"
[[ -f "$TEMPLATES/prompt.md" ]] || { echo "FAIL: prompt.md missing"; exit 1; }
grep -q "compressed" "$TEMPLATES/prompt.md" \
  || { echo "FAIL: prompt does not describe 'compressed' output"; exit 1; }
grep -q "semantic_risk_pct" "$TEMPLATES/prompt.md" \
  || { echo "FAIL: prompt does not describe 'semantic_risk_pct'"; exit 1; }
echo "PASS: prompt template present"

echo "Test 6: SKILL.md documents output + errors"
grep -q "^## Output$" "$SKILL_FILE" \
  || { echo "FAIL: '## Output' missing"; exit 1; }
grep -q "^## Errors$" "$SKILL_FILE" \
  || { echo "FAIL: '## Errors' missing"; exit 1; }
grep -q "anchors preserved" "$SKILL_FILE" \
  || { echo "FAIL: apply-mode anchor confirmation missing"; exit 1; }
echo "PASS: output + errors documented"

echo "Test 7: slash command exists"
CMD_FILE="$SCRIPT_DIR/commands/compress-skill.md"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE missing"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: compress-skill$" \
  || { echo "FAIL: command frontmatter missing"; exit 1; }
echo "PASS: slash command present"

echo "Test 8: bundle docs-discipline includes compress-skill"
BUNDLE="$SCRIPT_DIR/bundles/docs-discipline.yml"
grep -qE "^\s*-\s*compress-skill\s*$" "$BUNDLE" \
  || { echo "FAIL: compress-skill not listed in docs-discipline bundle"; exit 1; }
echo "PASS: bundle registration present"

echo "Test 9: wizard includes compress-skill"
WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*compress-skill.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: compress-skill not in items array"; exit 1; }
grep -q 'compress-skill|' "$WIZARD" \
  || { echo "FAIL: compress-skill hint missing"; exit 1; }
echo "PASS: wizard registration present"
