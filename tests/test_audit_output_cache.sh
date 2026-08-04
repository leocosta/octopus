#!/usr/bin/env bash
# tests/test_audit_output_cache.sh
#
# Since RM-172 the cache is code, not prose. Behaviour is covered by
# tests/test_audit_cache.sh; this suite guards the migration itself.
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

# T1: implementation and behaviour suite.
check "compiled cache exists" \
  test -f "$OCTOPUS_DIR/cli/lib/audit-cache.sh"
check "behaviour suite exists" \
  test -f "$OCTOPUS_DIR/tests/test_audit_cache.sh"

# T2: the shared fragment documents the contract and points at the code.
FRAGMENT="$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment exists" test -f "$FRAGMENT"
check "fragment points at the implementation" \
  grep -q "cli/lib/audit-cache.sh" "$FRAGMENT"
check "fragment documents the key derivation" \
  grep -q "sha256" "$FRAGMENT"
check "fragment documents the entry location" \
  grep -q ".octopus/cache" "$FRAGMENT"
check "fragment documents created_at frontmatter" \
  grep -q "created_at" "$FRAGMENT"
check "fragment records the ruleset limitation" \
  grep -qi "known limitation" "$FRAGMENT"

# T3: the write path is reachable from every audit.
for skill in "${AUDITS[@]}"; do
  check "$skill persists its report via --write" \
    grep -q "audit-scope $skill --write" "$OCTOPUS_DIR/skills/$skill/SKILL.md"
done

# T4: the prose protocol must not come back.
for skill in "${AUDITS[@]}"; do
  refute "$skill no longer asks the model to follow the prose cache protocol" \
    grep -q "follow the Cache protocol" "$OCTOPUS_DIR/skills/$skill/SKILL.md"
done

# T5: portability guarantee is asserted somewhere executable.
check "hash-tool agreement is covered by the behaviour suite" \
  grep -q "AUDIT_CACHE_HASH_TOOL" "$OCTOPUS_DIR/tests/test_audit_cache.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
