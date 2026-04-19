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
