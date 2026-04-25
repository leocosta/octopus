#!/usr/bin/env bash
# tests/test_audit_output_cache.sh
set -euo pipefail
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

# T1: shared fragment exists
check "shared fragment exists" \
  test -f "$OCTOPUS_DIR/skills/_shared/audit-cache.md"

# T2: fragment contains protocol markers
check "fragment contains 'Cache Check'" \
  grep -q "Cache Check" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'Cache Write'" \
  grep -q "Cache Write" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'CACHE_KEY'" \
  grep -q "CACHE_KEY" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'CACHE_FILE'" \
  grep -q "CACHE_FILE" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'sha256'" \
  grep -q "sha256" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains '.octopus/cache'" \
  grep -q ".octopus/cache" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"
check "fragment contains 'created_at'" \
  grep -q "created_at" "$OCTOPUS_DIR/skills/_shared/audit-cache.md"

# T3: each skill references audit-cache.md
check "audit-money references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/audit-money/SKILL.md"
check "audit-security references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/audit-security/SKILL.md"
check "review-contracts references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/review-contracts/SKILL.md"
check "audit-tenant references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/audit-tenant/SKILL.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
