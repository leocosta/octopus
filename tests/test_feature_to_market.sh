#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"

SKILL_FILE="$SCRIPT_DIR/skills/feature-to-market/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }

# Frontmatter must have name and description
head -n 5 "$SKILL_FILE" | grep -q "^name: feature-to-market$" \
  || { echo "FAIL: frontmatter 'name: feature-to-market' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description:' missing"; exit 1; }

echo "PASS: SKILL.md frontmatter valid"

echo "Test 2: SKILL.md documents invocation"

grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' section missing"; exit 1; }
grep -q "octopus:feature-to-market <ref>" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--channels" "--dry-run" "--no-images" "--images-only" "--angle" "--force"; do
  grep -q -- "$flag" "$SKILL_FILE" \
    || { echo "FAIL: flag $flag not documented"; exit 1; }
done

echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents input resolution and cascade"

grep -q "^## Input Resolution$" "$SKILL_FILE" \
  || { echo "FAIL: '## Input Resolution' missing"; exit 1; }
grep -q "^## Override Cascade$" "$SKILL_FILE" \
  || { echo "FAIL: '## Override Cascade' missing"; exit 1; }
grep -q "docs/marketing/" "$SKILL_FILE" \
  || { echo "FAIL: canonical override path missing"; exit 1; }
for name in brand voice audience hashtags social-media-guide social-media-hooks caption-templates viral-content-ideas; do
  grep -q "$name" "$SKILL_FILE" \
    || { echo "FAIL: override name '$name' missing"; exit 1; }
done

echo "PASS: input resolution + cascade documented"

echo "Test 4: default brand and voice templates exist"

TEMPLATES="$SCRIPT_DIR/skills/feature-to-market/templates"
for f in brand.md voice.md; do
  [[ -f "$TEMPLATES/$f" ]] || { echo "FAIL: template $f missing"; exit 1; }
  grep -q "^# " "$TEMPLATES/$f" || { echo "FAIL: $f has no H1"; exit 1; }
done

echo "PASS: brand + voice defaults present"

echo "Test 5: default audience + hashtags templates exist"

for f in audience.md hashtags.md; do
  [[ -f "$TEMPLATES/$f" ]] || { echo "FAIL: template $f missing"; exit 1; }
done

echo "PASS: audience + hashtags defaults present"

echo "Test 6: default strategy templates exist"

for f in social-media-guide.md social-media-hooks.md caption-templates.md viral-content-ideas.md video-roteiro.md; do
  [[ -f "$TEMPLATES/$f" ]] || { echo "FAIL: template $f missing"; exit 1; }
done

echo "PASS: strategy defaults present"

echo "Test 7: channel templates (IG, LI, X, email) exist"

CHANNELS="$TEMPLATES/channels"
for f in post-instagram.md post-linkedin.md thread-x.md email-lancamento.md; do
  [[ -f "$CHANNELS/$f" ]] || { echo "FAIL: channel template $f missing"; exit 1; }
  grep -q "^---$" "$CHANNELS/$f" || { echo "FAIL: $f missing frontmatter"; exit 1; }
done

echo "PASS: channel templates part 1 present"

echo "Test 8: channel templates (LP, changelog, video, images, README) exist"

for f in copy-lp.md changelog-vendedor.md roteiro-video.md image-prompts.md README.md; do
  [[ -f "$CHANNELS/$f" ]] || { echo "FAIL: channel template $f missing"; exit 1; }
done

echo "PASS: channel templates part 2 present"

echo "Test 9: SKILL.md documents output assembly"

grep -q "^## Output Assembly$" "$SKILL_FILE" \
  || { echo "FAIL: '## Output Assembly' missing"; exit 1; }
grep -q "docs/marketing/launches/" "$SKILL_FILE" \
  || { echo "FAIL: output path missing"; exit 1; }
grep -q "YYYY-MM-DD-<slug>" "$SKILL_FILE" \
  || { echo "FAIL: slug convention missing"; exit 1; }

echo "PASS: output assembly documented"

echo "Test 10: SKILL.md documents image generation"

grep -q "^## Image Generation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Image Generation' missing"; exit 1; }
grep -q "GEMINI_API_KEY" "$SKILL_FILE" \
  || { echo "FAIL: Gemini env var missing"; exit 1; }
grep -q "pollinations.ai" "$SKILL_FILE" \
  || { echo "FAIL: Pollinations fallback missing"; exit 1; }

echo "PASS: image generation documented"

echo "Test 11: SKILL.md documents errors and composition"

grep -q "^## Errors$" "$SKILL_FILE" \
  || { echo "FAIL: '## Errors' missing"; exit 1; }
grep -q "^## Composition with social-media role$" "$SKILL_FILE" \
  || { echo "FAIL: '## Composition with social-media role' missing"; exit 1; }

echo "PASS: errors and composition documented"
