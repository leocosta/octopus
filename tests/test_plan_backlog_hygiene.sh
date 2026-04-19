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

echo "Test 5: SKILL.md documents all six hygiene checks"
grep -q "^## Hygiene Checks$" "$SKILL_FILE" \
  || { echo "FAIL: '## Hygiene Checks' missing"; exit 1; }
for check in "H1" "H2" "H3" "H4" "H5" "H6"; do
  grep -q "^### $check " "$SKILL_FILE" \
    || { echo "FAIL: check $check missing"; exit 1; }
done
for keyword in "orphan" "concluded" "duplicate" "broken-link" "roadmap-orphan" "stale"; do
  grep -q "$keyword" "$SKILL_FILE" \
    || { echo "FAIL: check keyword '$keyword' missing"; exit 1; }
done
echo "PASS: all hygiene checks documented"

echo "Test 6: SKILL.md documents output + fix mode + errors"
grep -q "^## Output$" "$SKILL_FILE" \
  || { echo "FAIL: '## Output' missing"; exit 1; }
grep -q "^## Fix Mode$" "$SKILL_FILE" \
  || { echo "FAIL: '## Fix Mode' missing"; exit 1; }
grep -q "^## Errors$" "$SKILL_FILE" \
  || { echo "FAIL: '## Errors' missing"; exit 1; }
grep -q "plans/archive/" "$SKILL_FILE" \
  || { echo "FAIL: archive path missing"; exit 1; }
for sev in "🚫 Block" "⚠ Warn" "ℹ Info"; do
  grep -q -- "$sev" "$SKILL_FILE" || { echo "FAIL: severity '$sev' missing"; exit 1; }
done
echo "PASS: output + fix + errors documented"

echo "Test 7: slash command exists"
CMD_FILE="$SCRIPT_DIR/commands/plan-backlog-hygiene.md"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE missing"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: plan-backlog-hygiene$" \
  || { echo "FAIL: command frontmatter missing"; exit 1; }
echo "PASS: slash command present"

echo "Test 8: wizard includes plan-backlog-hygiene"
WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*plan-backlog-hygiene.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: plan-backlog-hygiene not in items array"; exit 1; }
echo "PASS: wizard registration present"
