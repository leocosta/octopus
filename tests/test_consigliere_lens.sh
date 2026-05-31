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

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
