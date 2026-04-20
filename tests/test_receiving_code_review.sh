#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/receiving-code-review/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: receiving-code-review$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md has Overview + When to Engage"
grep -q "^## Overview$" "$SKILL_FILE" \
  || { echo "FAIL: '## Overview' missing"; exit 1; }
grep -q "^## When to Engage$" "$SKILL_FILE" \
  || { echo "FAIL: '## When to Engage' missing"; exit 1; }
echo "PASS: Overview + When to Engage present"

echo "Test 3: SKILL.md documents all five rules"
grep -q "^## The Five Rules$" "$SKILL_FILE" \
  || { echo "FAIL: '## The Five Rules' missing"; exit 1; }
for h in "### Rule 1. Verify the critique against the code" "### Rule 2. Ask for evidence on generic comments" "### Rule 3. Separate reasoned feedback from preference" "### Rule 4. Never make performative changes" "### Rule 5. Ask for clarification on ambiguity"; do
  grep -qF "$h" "$SKILL_FILE" \
    || { echo "FAIL: rule header '$h' missing"; exit 1; }
done
echo "PASS: all five rules documented"
