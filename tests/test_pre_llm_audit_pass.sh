#!/usr/bin/env bash
# tests/test_pre_llm_audit_pass.sh
#
# Since RM-172 the pre-pass is code, not prose. Behaviour is covered by
# tests/test_audit_prepass.sh; this suite guards the migration itself — that the
# skills call the compiled entry point and that the protocol has not drifted back
# into instructions for the model to follow.
set -uo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

refute() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  else
    echo "PASS: $desc"; PASS=$((PASS + 1))
  fi
}

AUDITS=(audit-money audit-security audit-tenant audit-contracts)

# T1: the implementation exists and is the authority.
check "compiled pre-pass exists" \
  test -f "$OCTOPUS_DIR/cli/lib/audit-prepass.sh"
check "behaviour suite exists" \
  test -f "$OCTOPUS_DIR/tests/test_audit_prepass.sh"
check "audit-scope entry point exists" \
  test -f "$OCTOPUS_DIR/cli/lib/audit-scope.sh"
check "audit-scope is a registered command" \
  grep -q "^audit-scope|" "$OCTOPUS_DIR/cli/lib/commands.default"

# T2: the shared fragment documents the contract and points at the code.
FRAGMENT="$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment exists" test -f "$FRAGMENT"
check "fragment points at the implementation" \
  grep -q "cli/lib/audit-prepass.sh" "$FRAGMENT"
check "fragment documents the early exit" \
  grep -qi "early exit" "$FRAGMENT"
check "fragment documents the scoped diff" \
  grep -qi "scoped diff" "$FRAGMENT"
check "fragment warns about YAML escaping" \
  grep -q 'env' "$FRAGMENT"

# T3: every audit calls the compiled entry point, with its own name.
for skill in "${AUDITS[@]}"; do
  check "$skill calls octopus audit-scope $skill" \
    grep -q "octopus audit-scope $skill" "$OCTOPUS_DIR/skills/$skill/SKILL.md"
  check "$skill handles the three-path marker" \
    grep -q "cached" "$OCTOPUS_DIR/skills/$skill/SKILL.md"
  check "$skill still declares pre_pass" \
    grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/$skill/SKILL.md"
done

# T4: the prose protocol must not come back — a skill that tells the model to
# "follow the protocol" has silently reverted to the pre-RM-172 cost.
for skill in "${AUDITS[@]}"; do
  refute "$skill no longer asks the model to follow the prose pre-pass" \
    grep -q "Follow the Pre-Pass protocol" "$OCTOPUS_DIR/skills/$skill/SKILL.md"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
