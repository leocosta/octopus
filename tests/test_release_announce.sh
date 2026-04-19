#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/release-announce/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: release-announce$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:release-announce" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--theme" "--since" "--audience" "--channels" "--design-from" "--dry-run"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents input resolution and theme cascade"
grep -q "^## Input Resolution$" "$SKILL_FILE" \
  || { echo "FAIL: '## Input Resolution' missing"; exit 1; }
grep -q "^## Theme Resolution$" "$SKILL_FILE" \
  || { echo "FAIL: '## Theme Resolution' missing"; exit 1; }
grep -q "docs/release-announce/themes/" "$SKILL_FILE" \
  || { echo "FAIL: repo override path missing"; exit 1; }
grep -q "frontend-design" "$SKILL_FILE" \
  || { echo "FAIL: frontend-design integration missing"; exit 1; }
echo "PASS: resolution sections documented"
