#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_FILE="$SCRIPT_DIR/skills/doc-api/SKILL.md"
CMD_FILE="$SCRIPT_DIR/commands/doc-api.md"
BUNDLE_FILE="$SCRIPT_DIR/bundles/docs.yml"
SHARED_FMT="$SCRIPT_DIR/skills/_shared/audit-output-format.md"

echo "Test 1: SKILL.md exists with valid frontmatter"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 6 "$SKILL_FILE" | grep -q "^name: doc-api$" \
  || { echo "FAIL: frontmatter 'name: doc-api' missing"; exit 1; }
head -n 8 "$SKILL_FILE" | grep -q "^model: sonnet$" \
  || { echo "FAIL: frontmatter 'model: sonnet' missing"; exit 1; }
head -n 12 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: slash command exists and dispatches to the skill"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE missing"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: doc-api$" \
  || { echo "FAIL: command frontmatter 'name: doc-api' missing"; exit 1; }
grep -q "skills/doc-api/SKILL.md" "$CMD_FILE" \
  || { echo "FAIL: command does not dispatch to the skill"; exit 1; }
echo "PASS: slash command present"

echo "Test 3: registered in the docs bundle"
grep -q "^  - doc-api$" "$BUNDLE_FILE" \
  || { echo "FAIL: doc-api not registered in bundles/docs.yml"; exit 1; }
echo "PASS: bundle registration present"
