#!/usr/bin/env bash
# tests/test_playbook_review.sh
# Structural tests for the playbook-review skill (RM-103). Grep-based, per convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/playbook-review/SKILL.md"
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
check "playbook-review SKILL.md exists" test -f "$SKILL"
check "frontmatter name is playbook-review" grep -q "^name: playbook-review$" "$SKILL"
check "frontmatter has description" grep -q "^description:" "$SKILL"

# --- the proposal queue (inbox) -----------------------------------------
check "documents the playbook-inbox queue" grep -qi "playbook-inbox" "$SKILL"
check "documents the proposal block format" grep -qiE "observation|target:|evidence" "$SKILL"

# --- walk: promote / edit / discard -------------------------------------
check "documents promote" grep -qi "promote" "$SKILL"
check "documents edit" grep -qiE "\bedit\b|adjust|reword|retarget" "$SKILL"
check "documents discard" grep -qiE "discard|drop" "$SKILL"

# --- seed mode ----------------------------------------------------------
check "documents the --seed direct mode" grep -qiE "\-\-seed|seed mode|seed a heuristic" "$SKILL"

# --- per-node scope (no central playbook) -------------------------------
check "promotes into per-node playbook.md / people" \
  grep -qiE "playbook\.md|people/" "$SKILL"
check "no central playbook (per-node scope)" \
  grep -qiE "no central|per-node|scoped to the node" "$SKILL"

# --- grounding split ----------------------------------------------------
check "proposals must be grounded; seeds trusted" \
  grep -qiE "trusted|own knowledge|cite.*evidence|grounded" "$SKILL"
check "reuses audit-grounding" grep -qi "audit-grounding" "$SKILL"

# --- write-guard --------------------------------------------------------
check "writes only inside the workspace (write-guard)" \
  grep -qiE "write-guard|consigliere.workspace|inside the (configured )?workspace" "$SKILL"

# --- site docs ----------------------------------------------------------
check "site doc (EN) exists" test -f "$OCTOPUS_DIR/docs/site/skills/playbook-review.mdx"
check "site doc (pt-br) exists" test -f "$OCTOPUS_DIR/docs/site/pt-br/skills/playbook-review.mdx"

# --- summary ------------------------------------------------------------
echo "-----------------------------------------"
echo "playbook-review: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
