#!/usr/bin/env bash
# tests/test_consigliere_lens.sh — consigliere-lens helper (RM-110).
# Behavioral fixtures for the deterministic `octopus lens` helper + structural
# checks on the SKILL.md (mirrors tests/test_knowledge_hygiene.sh).
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
export KR_USER_YML="${TMPDIR:-/tmp}/cl-no-user-config-$$.yml"

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Run `octopus lens <args>` with a fixture workspace registered as the
# consigliere root.
lens() {
  local ws="$1"; shift
  ( cd "$ws" && env -u OCTOPUS_MEMORY_DIR CONSIGLIERE_WORKSPACE="$ws" \
      bash "$OCTOPUS_DIR/cli/octopus.sh" lens "$@" )
}

make_workspace() {
  local d; d="$(mktemp -d)"; mkdir -p "$d/contexts/payments"
  cat >"$d/contexts/payments/state.md" <<'MD'
# Payments

## Blockers
- fiscal approval stuck — owner: Ana — since 2026-05-20

## Political risk
- finance VP wants this slipped to Q3; pushing back risks the relationship
MD
  printf '# Playbook — payments\n- watch the fiscal sign-off\n' >"$d/contexts/payments/playbook.md"
  echo "$d"
}

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# Task 1 — `octopus lens profile <root>` returns the root's lens_profile
# ---------------------------------------------------------------------------
WS1="$(make_workspace)"; FIXTURES+=("$WS1")

t1_profile_consigliere() { [[ "$(lens "$WS1" profile consigliere)" == "consigliere" ]]; }

check "lens profile: returns the consigliere lens_profile"  t1_profile_consigliere

# ---------------------------------------------------------------------------
# Task 2 — `octopus lens context <node>` surfaces playbook + risk + blockers
# ---------------------------------------------------------------------------
WS2="$(make_workspace)"; FIXTURES+=("$WS2")
NODE2="$WS2/contexts/payments/state.md"

t2_context_playbook() {
  local o; o="$(lens "$WS2" context "$NODE2")"
  grep -q "playbook|$WS2/contexts/payments/playbook.md" <<<"$o"
}
t2_context_risk() {
  local o; o="$(lens "$WS2" context "$NODE2")"; grep -q 'risk|.*finance VP' <<<"$o"
}
t2_context_blocker() {
  local o; o="$(lens "$WS2" context "$NODE2")"; grep -q 'blocker|.*fiscal approval' <<<"$o"
}

check "lens context: surfaces sibling playbook"   t2_context_playbook
check "lens context: surfaces political risk"     t2_context_risk
check "lens context: surfaces blockers"           t2_context_blocker

# ---------------------------------------------------------------------------
# Task 3 — SKILL.md wrapper documents the lens (structural)
# ---------------------------------------------------------------------------
SKILL="$OCTOPUS_DIR/skills/consigliere-lens/SKILL.md"

t3_frontmatter()    { [[ -f "$SKILL" ]] && head -5 "$SKILL" | grep -q '^name: consigliere-lens$'; }
t3_invocation() {
  grep -q '^## Invocation$' "$SKILL" || return 1
  local f; for f in --engine --daily --weekly; do grep -q -- "$f" "$SKILL" || return 1; done
}
t3_names_consigliere_role() { grep -q 'consigliere' "$SKILL" && grep -qi 'opus' "$SKILL"; }
t3_requires_grounding()     { grep -q 'src:' "$SKILL"; }
t3_read_only_adr007()       { grep -qiE 'ADR-007|read-only|never write' "$SKILL"; }
t3_registered_in_bundle()   { grep -rqE '^ *- consigliere-lens( |$)' "$OCTOPUS_DIR/bundles"; }

check "skill: valid frontmatter"             t3_frontmatter
check "skill: documents invocation + flags"   t3_invocation
check "skill: names consigliere role + opus"  t3_names_consigliere_role
check "skill: requires (src:) grounding"      t3_requires_grounding
check "skill: read-only / ADR-007 write-guard" t3_read_only_adr007
check "skill: registered in a bundle"         t3_registered_in_bundle

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
