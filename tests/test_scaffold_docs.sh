#!/usr/bin/env bash
# tests/test_scaffold_docs.sh — site/scripts/scaffold-docs.sh (site-docs-overhaul).
# The generator fills only mechanical sections; curated prose is TODO; pages are
# created as drafts in EN + pt-br; existing pages are never overwritten.
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$OCTOPUS_DIR/site/scripts/scaffold-docs.sh"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

make_repo() {
  local r; r="$(mktemp -d)"; mkdir -p "$r/skills/demo-skill"
  cat >"$r/skills/demo-skill/SKILL.md" <<'MD'
---
name: demo-skill
description: >
  Does a demo thing grounded in RM-099 for the workspace, with a
  `--flag` it honours.
triggers:
  paths: []
---
# Demo
MD
  echo "$r"
}

REPO="$(make_repo)"; FIXTURES+=("$REPO")
DOCS="$(mktemp -d)"; FIXTURES+=("$DOCS")
gen() { SCAFFOLD_REPO_ROOT="$REPO" SCAFFOLD_DOCS_ROOT="$DOCS" bash "$GEN" skills "$@"; }

gen >/dev/null 2>&1

EN="$DOCS/skills/demo-skill.mdx"
PT="$DOCS/pt-br/skills/demo-skill.mdx"

t_creates_en()        { [[ -f "$EN" ]]; }
t_creates_pt()        { [[ -f "$PT" ]]; }
t_is_draft()          { grep -q '^draft: true$' "$EN"; }
t_has_title()         { grep -q '^title: demo-skill$' "$EN"; }
t_desc_present()      { grep -q 'Does a demo thing' "$EN"; }
t_desc_strips_leak()  { ! grep -q 'RM-099' "$EN"; }
t_curated_todo()      { grep -q '<!-- TODO' "$EN"; }
t_spine_sections()    { grep -q '## What it solves' "$EN" && grep -q '## How it works' "$EN"; }

# Idempotency: a pre-existing page is never overwritten.
t_never_overwrites() {
  local r d; r="$(make_repo)"; FIXTURES+=("$r"); d="$(mktemp -d)"; FIXTURES+=("$d")
  mkdir -p "$d/skills"; printf 'HAND-CURATED\n' >"$d/skills/demo-skill.mdx"
  SCAFFOLD_REPO_ROOT="$r" SCAFFOLD_DOCS_ROOT="$d" bash "$GEN" skills >/dev/null 2>&1
  grep -qx 'HAND-CURATED' "$d/skills/demo-skill.mdx"
}

check "scaffold: creates the EN page"               t_creates_en
check "scaffold: creates the pt-br page"            t_creates_pt
check "scaffold: page is a draft"                   t_is_draft
check "scaffold: title from the skill name"         t_has_title
check "scaffold: description carried over"          t_desc_present
check "scaffold: description strips leakage"        t_desc_strips_leak
check "scaffold: curated sections are TODO"         t_curated_todo
check "scaffold: spine sections present"            t_spine_sections
check "scaffold: never overwrites an existing page" t_never_overwrites

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
