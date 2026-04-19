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

echo "Test 7: last four preset themes exist with required fields"
for name in sunset ocean terminal paper; do
  f="$THEMES/${name}.yml"
  [[ -f "$f" ]] || { echo "FAIL: theme $name.yml missing"; exit 1; }
  grep -q "^name: ${name}$" "$f" \
    || { echo "FAIL: $name missing correct name field"; exit 1; }
  for field in description palette typography layout voice; do
    grep -q "^${field}:" "$f" \
      || { echo "FAIL: $name missing $field block"; exit 1; }
  done
done
echo "PASS: last four themes present"

echo "Test 8: canonical HTML templates exist"
HTML_DIR="$SCRIPT_DIR/skills/release-announce/templates/html"
for f in index.html.tmpl email.html.tmpl; do
  [[ -f "$HTML_DIR/$f" ]] || { echo "FAIL: $f missing"; exit 1; }
  grep -q "{{THEME_BACKGROUND}}" "$HTML_DIR/$f" \
    || { echo "FAIL: $f missing theme token {{THEME_BACKGROUND}}"; exit 1; }
  grep -q "{{RELEASE_TITLE}}" "$HTML_DIR/$f" \
    || { echo "FAIL: $f missing {{RELEASE_TITLE}}"; exit 1; }
done
if grep -q "<script" "$HTML_DIR/email.html.tmpl"; then
  echo "FAIL: email template contains <script>"; exit 1
fi
echo "PASS: canonical HTML templates present and constrained"

echo "Test 9: slides template exists and respects JS budget"
SLIDES="$HTML_DIR/slides.html.tmpl"
[[ -f "$SLIDES" ]] || { echo "FAIL: slides template missing"; exit 1; }
js_lines=$(awk '/<script>/{flag=1;next} /<\/script>/{flag=0} flag{print}' "$SLIDES" | wc -l)
[[ "$js_lines" -le 40 ]] \
  || { echo "FAIL: slides JS block is $js_lines lines, budget is 40"; exit 1; }
grep -q '{{THEME_PRIMARY}}' "$SLIDES" \
  || { echo "FAIL: slides missing theme token"; exit 1; }
grep -q '\.slide' "$SLIDES" \
  || { echo "FAIL: slides missing .slide selector/class"; exit 1; }
grep -q '{{SLIDES_HTML}}' "$SLIDES" \
  || { echo "FAIL: slides missing {{SLIDES_HTML}} placeholder"; exit 1; }
echo "PASS: slides template within JS budget"

echo "Test 10: first four channel templates exist"
CH_DIR="$SCRIPT_DIR/skills/release-announce/templates/channels"
for f in slack.md.tmpl discord.md.tmpl in-app-banner.md.tmpl status-page.md.tmpl; do
  [[ -f "$CH_DIR/$f" ]] || { echo "FAIL: channel template $f missing"; exit 1; }
  head -n 1 "$CH_DIR/$f" | grep -q "^---$" \
    || { echo "FAIL: $f missing frontmatter"; exit 1; }
done
echo "PASS: first four channel templates present with frontmatter"

echo "Test 11: remaining channel + canonical templates exist"
for f in x-announcement.md.tmpl whatsapp.md.tmpl; do
  [[ -f "$CH_DIR/$f" ]] || { echo "FAIL: channel template $f missing"; exit 1; }
done
TPL="$SCRIPT_DIR/skills/release-announce/templates"
for f in notes.md.tmpl readme.md.tmpl; do
  [[ -f "$TPL/$f" ]] || { echo "FAIL: canonical template $f missing"; exit 1; }
done
echo "PASS: remaining templates present"

echo "Test 12: slash command + wizard + bundle + README + skills.md"
CMD="$SCRIPT_DIR/commands/release-announce.md"
[[ -f "$CMD" ]] || { echo "FAIL: command file missing"; exit 1; }
head -n 5 "$CMD" | grep -q "^name: release-announce$" \
  || { echo "FAIL: command frontmatter missing"; exit 1; }

WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"
grep -E "^[[:space:]]*local items=\(.*release-announce.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: release-announce not in wizard items"; exit 1; }

BUNDLE="$SCRIPT_DIR/bundles/growth.yml"
grep -q -- "- release-announce" "$BUNDLE" \
  || { echo "FAIL: growth bundle missing release-announce"; exit 1; }

grep -q "release-announce" "$SCRIPT_DIR/README.md" \
  || { echo "FAIL: README missing release-announce"; exit 1; }

grep -q "release-announce" "$SCRIPT_DIR/docs/features/skills.md" \
  || { echo "FAIL: skills.md missing release-announce row"; exit 1; }

echo "PASS: command + wizard + bundle + docs wired"
