#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/plan-backlog-hygiene/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: plan-backlog-hygiene$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:plan-backlog-hygiene" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--fix" "--write-report" "--plans-dir" "--stale-days" "--only"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents plans directory discovery"
grep -q "^## Plans Directory Discovery$" "$SKILL_FILE" \
  || { echo "FAIL: '## Plans Directory Discovery' missing"; exit 1; }
grep -q "plansDir:" "$SKILL_FILE" \
  || { echo "FAIL: plansDir field reference missing"; exit 1; }
echo "PASS: discovery documented"

echo "Test 4: patterns template exists"
TEMPLATES="$SCRIPT_DIR/skills/plan-backlog-hygiene/templates"
[[ -f "$TEMPLATES/patterns.md" ]] || { echo "FAIL: patterns.md missing"; exit 1; }
echo "PASS: patterns template present"
