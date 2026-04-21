#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/cross-stack-contract/SKILL.md"
SHARED_FILE="$SCRIPT_DIR/skills/_shared/audit-output-format.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
[[ -f "$SHARED_FILE" ]] || { echo "FAIL: shared audit-output-format.md missing"; exit 1; }
grep_docs() { cat "$SKILL_FILE" "$SHARED_FILE" | grep -q "$@"; }
head -n 5 "$SKILL_FILE" | grep -q "^name: cross-stack-contract$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:cross-stack-contract" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--base" "--stacks" "--only" "--write-report"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents stack discovery"
grep -q "^## Stack Discovery$" "$SKILL_FILE" \
  || { echo "FAIL: '## Stack Discovery' missing"; exit 1; }
grep -q "\.octopus\.yml" "$SKILL_FILE" \
  || { echo "FAIL: manifest override mention missing"; exit 1; }
grep -q "stacks:" "$SKILL_FILE" \
  || { echo "FAIL: stacks map reference missing"; exit 1; }
echo "PASS: stack discovery documented"

echo "Test 4: default patterns template exists"
TEMPLATES="$SCRIPT_DIR/skills/cross-stack-contract/templates"
[[ -f "$TEMPLATES/patterns.md" ]] || { echo "FAIL: patterns.md missing"; exit 1; }
echo "PASS: patterns template present"

echo "Test 5: SKILL.md documents all seven inspection checks"
grep -q "^## Inspection Checks$" "$SKILL_FILE" \
  || { echo "FAIL: '## Inspection Checks' missing"; exit 1; }
for check in "C1" "C2" "C3" "C4" "C5" "C6" "C7"; do
  grep -q "^### $check " "$SKILL_FILE" \
    || { echo "FAIL: check $check missing"; exit 1; }
done
for keyword in "endpoint-added" "endpoint-removed" "dto" "enum" "status" "auth" "params"; do
  grep -q "$keyword" "$SKILL_FILE" \
    || { echo "FAIL: check keyword '$keyword' missing"; exit 1; }
done
echo "PASS: all inspection checks documented"

echo "Test 6: SKILL.md documents output + errors"
grep -q "^## Output$" "$SKILL_FILE" \
  || { echo "FAIL: '## Output' missing"; exit 1; }
grep -q "^## Errors$" "$SKILL_FILE" \
  || { echo "FAIL: '## Errors' missing"; exit 1; }
grep_docs "docs/reviews/" \
  || { echo "FAIL: report path missing"; exit 1; }
for sev in "🚫 Block" "⚠ Warn" "ℹ Info"; do
  grep_docs -- "$sev" || { echo "FAIL: severity '$sev' missing"; exit 1; }
done
grep_docs "confidence" || { echo "FAIL: confidence label missing"; exit 1; }
echo "PASS: output + errors documented"

echo "Test 7: slash command exists"
CMD_FILE="$SCRIPT_DIR/commands/cross-stack-contract.md"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE missing"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: cross-stack-contract$" \
  || { echo "FAIL: command frontmatter missing"; exit 1; }
echo "PASS: slash command present"

echo "Test 8: wizard includes cross-stack-contract"
WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*cross-stack-contract.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: cross-stack-contract not in items array"; exit 1; }
echo "PASS: wizard registration present"
