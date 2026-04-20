#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/audit-all/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: audit-all$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:audit-all" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--base" "--only" "--write-report"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents discovery + parallel execution"
for section in "^## Shared File Discovery$" "^## Parallel Execution$"; do
  grep -qE "$section" "$SKILL_FILE" \
    || { echo "FAIL: '$section' missing"; exit 1; }
done
grep -q "superpowers:dispatching-parallel-agents" "$SKILL_FILE" \
  || { echo "FAIL: parallel dispatch reference missing"; exit 1; }
grep -q "domain" "$SKILL_FILE" \
  || { echo "FAIL: domain tagging mention missing"; exit 1; }
echo "PASS: discovery + parallel sections documented"
