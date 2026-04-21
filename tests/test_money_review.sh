#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"

SKILL_FILE="$SCRIPT_DIR/skills/money-review/SKILL.md"
SHARED_FILE="$SCRIPT_DIR/skills/_shared/audit-output-format.md"
[[ -f "$SHARED_FILE" ]] || { echo "FAIL: shared audit-output-format.md missing"; exit 1; }

# Check across SKILL.md + shared conventions file.
grep_docs() { cat "$SKILL_FILE" "$SHARED_FILE" | grep -q "$@"; }
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: money-review$" \
  || { echo "FAIL: frontmatter 'name: money-review' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description:' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:money-review" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--base" "--write-report" "--only"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag not documented"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents file discovery and overrides"
grep -q "^## File Discovery$" "$SKILL_FILE" \
  || { echo "FAIL: '## File Discovery' missing"; exit 1; }
grep_docs "docs/money-review/patterns.md\|docs/<skill-name>/patterns.md" \
  || { echo "FAIL: override path missing"; exit 1; }
echo "PASS: file discovery documented"

echo "Test 4: template defaults exist"
TEMPLATES="$SCRIPT_DIR/skills/money-review/templates"
for f in patterns.md providers.md; do
  [[ -f "$TEMPLATES/$f" ]] || { echo "FAIL: $f missing"; exit 1; }
done
echo "PASS: templates present"

echo "Test 5: SKILL.md documents all seven inspection families"
grep -q "^## Inspection Families$" "$SKILL_FILE" \
  || { echo "FAIL: '## Inspection Families' missing"; exit 1; }
for fam in "T1" "T2" "T3" "T4" "T5" "T6" "T7"; do
  grep -q "^### $fam " "$SKILL_FILE" \
    || { echo "FAIL: family $fam missing"; exit 1; }
done
for keyword in "types" "rounding" "tests" "env" "idempotency" "webhook" "disclosure"; do
  grep -q "\b$keyword\b" "$SKILL_FILE" \
    || { echo "FAIL: family keyword '$keyword' missing"; exit 1; }
done
echo "PASS: all inspection families documented"

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
echo "PASS: output + errors documented"

echo "Test 7: slash command exists"
CMD_FILE="$SCRIPT_DIR/commands/money-review.md"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE missing"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: money-review$" \
  || { echo "FAIL: command frontmatter missing"; exit 1; }
echo "PASS: slash command present"

echo "Test 8: wizard includes money-review"
WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*money-review.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: money-review not in items array"; exit 1; }
echo "PASS: wizard registration present"
