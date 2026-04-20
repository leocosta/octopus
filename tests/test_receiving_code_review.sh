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

echo "Test 4: SKILL.md has Task Routing + Integration + Anti-Patterns"
for section in "^## Task Routing$" "^## Integration with Other Skills$" "^## Anti-Patterns$"; do
  grep -qE "$section" "$SKILL_FILE" \
    || { echo "FAIL: '$section' missing"; exit 1; }
done

echo "Test 5: Task Routing stub references RM-034"
grep -q "RM-034" "$SKILL_FILE" \
  || { echo "FAIL: Task Routing stub does not mention RM-034"; exit 1; }

echo "Test 6: Anti-Patterns forbids key anti-patterns"
for pattern in "performative" "generic comment" "preference" "ambiguity" "Batching"; do
  grep -qF "$pattern" "$SKILL_FILE" \
    || { echo "FAIL: Anti-Patterns missing '$pattern'"; exit 1; }
done
echo "PASS: routing + integration + anti-patterns documented"

echo "Test 7: slash command + wizard registration"
CMD="$SCRIPT_DIR/commands/receiving-code-review.md"
[[ -f "$CMD" ]] || { echo "FAIL: command file missing"; exit 1; }
head -n 5 "$CMD" | grep -q "^name: receiving-code-review$" \
  || { echo "FAIL: command frontmatter 'name' missing"; exit 1; }

WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*receiving-code-review.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: receiving-code-review not in wizard items array"; exit 1; }
grep -q "receiving-code-review|" "$WIZARD" \
  || { echo "FAIL: receiving-code-review not in wizard hints"; exit 1; }
echo "PASS: command + wizard wired"

echo "Test 8: starter bundle includes receiving-code-review"
BUNDLE="$SCRIPT_DIR/bundles/starter.yml"
grep -q -- "- receiving-code-review" "$BUNDLE" \
  || { echo "FAIL: receiving-code-review missing from starter bundle"; exit 1; }
echo "PASS: starter bundle lists receiving-code-review"

echo "Test 9: README + skills.md list receiving-code-review + tutorial exists"
grep -q "receiving-code-review" "$SCRIPT_DIR/README.md" \
  || { echo "FAIL: README missing 'receiving-code-review'"; exit 1; }
grep -q "| \`receiving-code-review\` |" "$SCRIPT_DIR/docs/features/skills.md" \
  || { echo "FAIL: skills.md missing receiving-code-review row"; exit 1; }
TUTORIAL="$SCRIPT_DIR/docs/features/receiving-code-review.md"
[[ -f "$TUTORIAL" ]] || { echo "FAIL: tutorial $TUTORIAL missing"; exit 1; }
echo "PASS: README + skills.md + tutorial wired"
