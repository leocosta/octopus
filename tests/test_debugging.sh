#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/debugging/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: debugging$" \
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

echo "Test 3: SKILL.md documents all four phases"
grep -q "^## The Four Phases$" "$SKILL_FILE" \
  || { echo "FAIL: '## The Four Phases' missing"; exit 1; }
for h in "### Phase 1. Reproduce deterministically" "### Phase 2. Isolate" "### Phase 3. Fix with a regression test first" "### Phase 4. Document non-obvious cause"; do
  grep -qF "$h" "$SKILL_FILE" \
    || { echo "FAIL: phase header '$h' missing"; exit 1; }
done
echo "PASS: all four phases documented"

echo "Test 4: SKILL.md has Task Routing + Integration + Anti-Patterns"
for section in "^## Task Routing$" "^## Integration with Other Skills$" "^## Anti-Patterns$"; do
  grep -qE "$section" "$SKILL_FILE" \
    || { echo "FAIL: '$section' missing"; exit 1; }
done

echo "Test 5: Task Routing stub references RM-034"
grep -q "RM-034" "$SKILL_FILE" \
  || { echo "FAIL: Task Routing stub does not mention RM-034"; exit 1; }

echo "Test 6: Anti-Patterns forbids key anti-patterns"
for pattern in "without reproducing" "regression test" "Silent retry" "feature flag" "Macro-commits"; do
  grep -qF "$pattern" "$SKILL_FILE" \
    || { echo "FAIL: Anti-Patterns missing '$pattern'"; exit 1; }
done
echo "PASS: routing + integration + anti-patterns documented"

echo "Test 7: slash command + wizard registration"
CMD="$SCRIPT_DIR/commands/debugging.md"
[[ -f "$CMD" ]] || { echo "FAIL: command file missing"; exit 1; }
head -n 5 "$CMD" | grep -q "^name: debugging$" \
  || { echo "FAIL: command frontmatter 'name' missing"; exit 1; }

WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*debugging.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: debugging not in wizard items array"; exit 1; }
grep -q "debugging|" "$WIZARD" \
  || { echo "FAIL: debugging not in wizard hints"; exit 1; }
echo "PASS: command + wizard wired"

echo "Test 8: starter bundle includes debugging"
BUNDLE="$SCRIPT_DIR/bundles/starter.yml"
grep -q -- "- debugging" "$BUNDLE" \
  || { echo "FAIL: debugging missing from starter bundle"; exit 1; }
echo "PASS: starter bundle lists debugging"
