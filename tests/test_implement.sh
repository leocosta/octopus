#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/implement/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: implement$" \
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

echo "Test 3: SKILL.md documents all five practices"
grep -q "^## The Five Practices$" "$SKILL_FILE" \
  || { echo "FAIL: '## The Five Practices' missing"; exit 1; }
for h in "### 1. TDD loop" "### 2. Plan-before-code gate" "### 3. Verification-before-completion" "### 4. Simplify pass" "### 5. Commit cadence"; do
  grep -qF "$h" "$SKILL_FILE" \
    || { echo "FAIL: practice header '$h' missing"; exit 1; }
done
echo "PASS: all five practices documented"
