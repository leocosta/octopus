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
check "money-review references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/money-review/SKILL.md"
check "security-scan references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/security-scan/SKILL.md"
check "cross-stack-contract references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md"
check "tenant-scope-audit references audit-cache.md" \
  grep -q "audit-cache.md" "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
