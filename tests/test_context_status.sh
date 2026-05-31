#!/usr/bin/env bash
# tests/test_context_status.sh
# Structural tests for the context-status skill (RM-102). Grep-based, per convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/context-status/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- exists + frontmatter -----------------------------------------------
check "context-status SKILL.md exists" test -f "$SKILL"
check "frontmatter name is context-status" grep -q "^name: context-status$" "$SKILL"
check "frontmatter has description" grep -q "^description:" "$SKILL"

# --- read-only ----------------------------------------------------------
check "documents read-only / never writes" \
  grep -qiE "read-only|never writes?|no writes?|does not write" "$SKILL"

# --- workspace resolution + write-guard (read scope) --------------------
check "resolves consigliere.workspace" grep -q "consigliere.workspace" "$SKILL"
check "cites the write-guard / read stays in workspace" \
  grep -qiE "write-guard|within the (resolved )?workspace|inside the (configured )?workspace" "$SKILL"

# --- routing: infer + confirm -------------------------------------------
check "infers the target from the question" grep -qiE "infer|interpret|map the question" "$SKILL"
check "confirms / asks on ambiguity" grep -qiE "ambigu|confirm|ask, never guess|never guess" "$SKILL"

# --- reads the materialized state ---------------------------------------
check "reads the materialized state.md" grep -qi "state.md" "$SKILL"
check "drills into journal/detail only when needed" \
  grep -qiE "journal.md|history|drill|when the question needs" "$SKILL"

# --- grounding ----------------------------------------------------------
check "strict grounding with provenance" \
  grep -qiE "grounding|src:|provenance|traces? to" "$SKILL"
check "reuses audit-grounding" grep -qi "audit-grounding" "$SKILL"
check "answers 'not recorded' instead of inventing" \
  grep -qiE "not recorded|never invent|do not guess|points? (you )?at .*digest-source" "$SKILL"

# --- consigliere lens ---------------------------------------------------
check "applies the consigliere lens" grep -qiE "consigliere (role|lens)|political risk|heuristic" "$SKILL"

# --- site docs ----------------------------------------------------------
check "site doc (EN) exists" test -f "$OCTOPUS_DIR/docs/site/skills/context-status.mdx"
check "site doc (pt-br) exists" test -f "$OCTOPUS_DIR/docs/site/pt-br/skills/context-status.mdx"

# --- summary ------------------------------------------------------------
echo "-----------------------------------------"
echo "context-status: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
