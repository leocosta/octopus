#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"

SKILL_FILE="$SCRIPT_DIR/skills/money-review/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: money-review$" \
  || { echo "FAIL: frontmatter 'name: money-review' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description:' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:money-review" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--base" "--write-report" "--only"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag not documented"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents file discovery and overrides"
grep -q "^## File Discovery$" "$SKILL_FILE" \
  || { echo "FAIL: '## File Discovery' missing"; exit 1; }
grep -q "docs/money-review/patterns.md" "$SKILL_FILE" \
  || { echo "FAIL: override path missing"; exit 1; }
echo "PASS: file discovery documented"

echo "Test 4: template defaults exist"
TEMPLATES="$SCRIPT_DIR/skills/money-review/templates"
for f in patterns.md providers.md; do
  [[ -f "$TEMPLATES/$f" ]] || { echo "FAIL: $f missing"; exit 1; }
done
echo "PASS: templates present"
