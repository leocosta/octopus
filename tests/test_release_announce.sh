#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/release-announce/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: release-announce$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:release-announce" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--theme" "--since" "--audience" "--channels" "--design-from" "--dry-run"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents input resolution and theme cascade"
grep -q "^## Input Resolution$" "$SKILL_FILE" \
  || { echo "FAIL: '## Input Resolution' missing"; exit 1; }
grep -q "^## Theme Resolution$" "$SKILL_FILE" \
  || { echo "FAIL: '## Theme Resolution' missing"; exit 1; }
grep -q "docs/release-announce/themes/" "$SKILL_FILE" \
  || { echo "FAIL: repo override path missing"; exit 1; }
grep -q "frontend-design" "$SKILL_FILE" \
  || { echo "FAIL: frontend-design integration missing"; exit 1; }
echo "PASS: resolution sections documented"

echo "Test 4: SKILL.md documents output structure + theme schema"
for section in "^## Output$" "^## Theme Schema$" "^## Slides Channel$"; do
  grep -qE "$section" "$SKILL_FILE" \
    || { echo "FAIL: section '$section' missing"; exit 1; }
done
grep -q "docs/releases/YYYY-MM-DD-" "$SKILL_FILE" \
  || { echo "FAIL: output path convention missing"; exit 1; }
for token in "palette" "typography" "layout" "voice" "hero" "grouping" "density"; do
  grep -q "$token" "$SKILL_FILE" \
    || { echo "FAIL: theme schema token '$token' missing"; exit 1; }
done
echo "PASS: output + schema documented"

echo "Test 5: SKILL.md documents errors and composition"
grep -q "^## Errors$" "$SKILL_FILE" \
  || { echo "FAIL: '## Errors' missing"; exit 1; }
grep -q "^## Composition$" "$SKILL_FILE" \
  || { echo "FAIL: '## Composition' missing"; exit 1; }
echo "PASS: errors + composition documented"

echo "Test 6: first five preset themes exist with required fields"
THEMES="$SCRIPT_DIR/skills/release-announce/templates/themes"
for name in classic jade dark bold newsletter; do
  f="$THEMES/${name}.yml"
  [[ -f "$f" ]] || { echo "FAIL: theme $name.yml missing"; exit 1; }
  grep -q "^name: ${name}$" "$f" \
    || { echo "FAIL: $name missing correct name field"; exit 1; }
  for field in description palette typography layout voice; do
    grep -q "^${field}:" "$f" \
      || { echo "FAIL: $name missing $field block"; exit 1; }
  done
done
echo "PASS: first five themes present"
