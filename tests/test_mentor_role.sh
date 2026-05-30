#!/usr/bin/env bash
# tests/test_mentor_role.sh
# Structural tests for the mentor review role (RM-089).
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLE="$OCTOPUS_DIR/roles/mentor.md"
DELEGATE="$OCTOPUS_DIR/skills/delegate/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- the role file ------------------------------------------------------
check "role exists" test -f "$ROLE"
check "frontmatter name: mentor" grep -q "^name: mentor" "$ROLE"
check "frontmatter has a description" grep -q "^description:" "$ROLE"
check "frontmatter declares a model" grep -q "^model:" "$ROLE"

# --- mission: teach the why ---------------------------------------------
check "mission is to teach the why" grep -qiE "teach" "$ROLE"

# --- input: consumes already-produced findings from the gate roles ------
check "consumes architect findings" grep -qi "architect" "$ROLE"
check "consumes dba findings" grep -qi "dba" "$ROLE"
check "consumes security findings" grep -qi "security" "$ROLE"
check "reads already-produced findings (pr-review/codereview report)" grep -qiE "pr-review|codereview|report" "$ROLE"
check "does not re-run / re-analyze the roles" grep -qiE "not re-?run|does not re-?analyze|already-produced|already produced|not re-?analyze" "$ROLE"
check "tags each unit with its origin role" grep -qiE "origin|\[architect\]|\[dba\]|\[security\]" "$ROLE"

# --- teaching-unit output shape -----------------------------------------
check "teaching-unit shape: principle" grep -qiE "principle" "$ROLE"
check "teaching-unit shape: why it matters" grep -qiE "why it matters|why this matters|matters" "$ROLE"
check "teaching-unit shape: better approach" grep -qiE "better approach|what to do instead|better path" "$ROLE"
check "teaching-unit shape: read-more / source" grep -qiE "read more|read-more|source" "$ROLE"

# --- source citation + gap signal ---------------------------------------
check "cites team sources (rules/adr/CONTEXT)" grep -qE "rules/|docs/adr|CONTEXT.md" "$ROLE"
check "notes a standards gap inline when undocumented" grep -qiE "gap|not documented|undocumented|no .* source" "$ROLE"

# --- boundary: non-gate, default read-only ------------------------------
check "never gates (no blocking/approval verdict)" grep -qiE "never gate|not a gate|does not gate|never block|no.*verdict" "$ROLE"
check "default is inline-only / read-only (no writes)" grep -qiE "inline only|inline-only|read-only|writes nothing|by default.*(no|never).*writ" "$ROLE"
check "does not edit code / the diff" grep -qiE "never edit|does not edit|not.*rewrite|never modif" "$ROLE"

# --- flags: --save and --pr ---------------------------------------------
check "declares --save flag" grep -q -- "--save" "$ROLE"
check "--save writes docs/mentoring lesson log" grep -q "docs/mentoring" "$ROLE"
check "--save writes standards-gap stub to proposals" grep -q ".octopus/proposals" "$ROLE"
check "declares --pr flag" grep -q -- "--pr" "$ROLE"
check "--pr posts inline PR comments" grep -qiE "pr comment|comment.*pr|gh pr comment|inline.*comment" "$ROLE"

# --- delegate wiring ----------------------------------------------------
check "delegate alias table includes mentor" grep -qi "mentor" "$DELEGATE"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
