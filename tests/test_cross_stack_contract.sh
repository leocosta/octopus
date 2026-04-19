#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/cross-stack-contract/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
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
