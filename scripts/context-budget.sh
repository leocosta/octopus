#!/usr/bin/env bash
# scripts/context-budget.sh
# RM-131 — deterministic measurement of the always-loaded context budget.
#
# Reports the token cost that loads into EVERY session of a repo: the generated
# CLAUDE.md, the always-loaded rules, and the registry listing (the
# `description:` frontmatter of skills/commands that the harness lists each
# session). Also flags the core<->rules duplication that RM-117 removes.
#
# Pure measurement: never edits anything, always exits 0. The CI ratchet lives
# in tests/test_context_budget.sh, which parses the `TOTAL_TOKENS=` line below.
#
# Token estimate: ~4 characters per token (the same rough ratio the
# context-budget skill documents). Bytes are exact; tokens are an estimate.
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# --- helpers ---------------------------------------------------------------

# Sum bytes of the files passed as args (missing files count as 0).
_bytes() {
  local total=0 f sz
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    sz=$(wc -c <"$f" 2>/dev/null || echo 0)
    total=$((total + sz))
  done
  echo "$total"
}

_tokens() { echo $(( ${1:-0} / 4 )); }  # ~4 chars/token

# Resolve the measured paths. Prefer the repo SOURCE tree (the canonical thing
# the refactor optimizes — rules/, skills/, commands/); fall back to the
# materialized `.claude/` artifacts for a consumer repo that has no source tree.
_first_existing_dir() {
  local d; for d in "$@"; do [[ -d "$d" ]] && { echo "$d"; return 0; }; done
  return 1
}

# CLAUDE.md is generated; the loaded artifact lives at .claude/CLAUDE.md.
CLAUDE_MD="$ROOT/.claude/CLAUDE.md"
[[ -f "$CLAUDE_MD" ]] || CLAUDE_MD="$ROOT/CLAUDE.md"
RULES_DIR="$(_first_existing_dir "$ROOT/rules/common" "$ROOT/.claude/rules/common" || true)"
SKILLS_DIR="$(_first_existing_dir "$ROOT/skills" "$ROOT/.claude/skills" || true)"
COMMANDS_DIR="$(_first_existing_dir "$ROOT/commands" "$ROOT/.claude/commands" || true)"

# --- 1. CLAUDE.md ----------------------------------------------------------
claude_bytes=$(_bytes "$CLAUDE_MD")

# --- 2. always-loaded rules ------------------------------------------------
rules_bytes=0
if [[ -n "$RULES_DIR" ]]; then
  # -L: follow symlinks (rules are symlinked into .claude/rules/).
  while IFS= read -r f; do
    rules_bytes=$((rules_bytes + $(wc -c <"$f" 2>/dev/null || echo 0)))
  done < <(find -L "$RULES_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null)
fi

# --- 3. registry listing (sum of `description:` frontmatter) ---------------
# This is the text the harness lists for every skill/command each session.
_description_bytes() {
  local dir="$1" name="$2" total=0 line
  [[ -n "$dir" && -d "$dir" ]] || { echo 0; return; }
  while IFS= read -r line; do
    total=$((total + ${#line}))
  done < <(find -L "$dir" -name "$name" -type f -exec grep -hE '^description:' {} + 2>/dev/null)
  echo "$total"
}
skills_desc_bytes=$(_description_bytes "$SKILLS_DIR" "SKILL.md")
cmds_desc_bytes=$(_description_bytes "$COMMANDS_DIR" "*.md")
registry_bytes=$((skills_desc_bytes + cmds_desc_bytes))

# --- totals ----------------------------------------------------------------
always_bytes=$((claude_bytes + rules_bytes))
always_tokens=$(_tokens "$always_bytes")
registry_tokens=$(_tokens "$registry_bytes")
total_tokens=$((always_tokens + registry_tokens))

# --- 4. duplication signal (core<->rules) ----------------------------------
# RM-117 target: the inlined coding guidelines must not also be loaded via
# rules/common. Heuristic: a marker phrase present in BOTH CLAUDE.md and
# rules/common/coding-style.md means it loads twice.
dup_markers=0
coding_style="$RULES_DIR/coding-style.md"
if [[ -f "$CLAUDE_MD" && -f "$coding_style" ]]; then
  for marker in "Readability over cleverness" "God objects" "Premature optimization"; do
    if grep -qF "$marker" "$CLAUDE_MD" && grep -qF "$marker" "$coding_style"; then
      dup_markers=$((dup_markers + 1))
    fi
  done
fi

# --- report ----------------------------------------------------------------
printf 'Context Budget Report — %s\n' "$ROOT"
printf '=====================================\n'
printf '  CLAUDE.md (generated)     %7d bytes  ~%5d tok\n' "$claude_bytes" "$(_tokens "$claude_bytes")"
printf '  rules (always loaded)     %7d bytes  ~%5d tok\n' "$rules_bytes" "$(_tokens "$rules_bytes")"
printf '  -----------------------------------------------\n'
printf '  Always-loaded baseline    %7d bytes  ~%5d tok\n' "$always_bytes" "$always_tokens"
printf '  Registry descriptions     %7d bytes  ~%5d tok  (skills+commands listing)\n' "$registry_bytes" "$registry_tokens"
printf '  -----------------------------------------------\n'
printf '  TOTAL per session                          ~%5d tok\n' "$total_tokens"
printf '\n'
printf '  core<->rules duplicated markers: %d  (target: 0 — RM-117)\n' "$dup_markers"
printf '\n'
# Machine-readable line for the CI ratchet (tests/test_context_budget.sh).
printf 'ALWAYS_TOKENS=%d REGISTRY_TOKENS=%d TOTAL_TOKENS=%d DUP_MARKERS=%d\n' \
  "$always_tokens" "$registry_tokens" "$total_tokens" "$dup_markers"
