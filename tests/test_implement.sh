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

echo "Test 4: SKILL.md has Task Routing + Integration + Anti-Patterns"
for section in "^## Task Routing$" "^## Integration with Other Skills$" "^## Anti-Patterns$"; do
  grep -qE "$section" "$SKILL_FILE" \
    || { echo "FAIL: '$section' missing"; exit 1; }
done

echo "Test 5: Task Routing section embeds the shared canonical fragment"
grep -q "<!-- BEGIN task-routing -->" "$SKILL_FILE" \
  || { echo "FAIL: Task Routing section missing the shared-fragment marker"; exit 1; }

echo "Test 6: Anti-Patterns forbids key anti-patterns"
for pattern in "no-verify" "Macro-commit" "Premature abstraction" "rules/common"; do
  grep -qF "$pattern" "$SKILL_FILE" \
    || { echo "FAIL: Anti-Patterns missing '$pattern'"; exit 1; }
done
echo "PASS: routing + integration + anti-patterns documented"

echo "Test 7: slash command + wizard registration"
CMD="$SCRIPT_DIR/commands/implement.md"
[[ -f "$CMD" ]] || { echo "FAIL: command file missing"; exit 1; }
head -n 5 "$CMD" | grep -q "^name: implement$" \
  || { echo "FAIL: command frontmatter 'name' missing"; exit 1; }

WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*implement.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: implement not in wizard items array"; exit 1; }
grep -q "implement|" "$WIZARD" \
  || { echo "FAIL: implement not in wizard hints"; exit 1; }
echo "PASS: command + wizard wired"

echo "Test 8: starter bundle includes implement"
BUNDLE="$SCRIPT_DIR/bundles/starter.yml"
grep -q -- "- implement" "$BUNDLE" \
  || { echo "FAIL: implement missing from starter bundle"; exit 1; }
echo "PASS: starter bundle lists implement"

echo "Test 9: README + skills.md list implement"
grep -q "implement" "$SCRIPT_DIR/README.md" \
  || { echo "FAIL: README missing 'implement'"; exit 1; }
grep -q "| \`implement\` |" "$SCRIPT_DIR/docs/features/skills.md" \
  || { echo "FAIL: skills.md missing implement row"; exit 1; }
TUTORIAL="$SCRIPT_DIR/docs/features/implement.md"
[[ -f "$TUTORIAL" ]] || { echo "FAIL: tutorial $TUTORIAL missing"; exit 1; }
echo "PASS: README + skills.md + tutorial wired"
