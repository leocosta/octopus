#!/usr/bin/env bash
# tests/test_bundle_preview.sh
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

WIZARD="$OCTOPUS_DIR/cli/lib/setup-wizard.sh"

# T1: _skill_impact_table function exists
check "_skill_impact_table function defined" \
  grep -q "_skill_impact_table()" "$WIZARD"

# T2: function uses wc -l to count lines
check "_skill_impact_table uses wc -l" \
  bash -c 'grep -A30 "_skill_impact_table()" "$1" | grep -q "wc -l"' _ "$WIZARD"

# T3: function computes token estimate (multiplied by 4)
check "_skill_impact_table computes tokens" \
  bash -c 'grep -A30 "_skill_impact_table()" "$1" | grep -qE "\* 4|\*4"' _ "$WIZARD"

# T4: _wizard_sub_skills calls _skill_impact_table
check "_wizard_sub_skills calls _skill_impact_table" \
  bash -c 'grep -A70 "_wizard_sub_skills\(\)" "$1" | grep -q "_skill_impact_table"' _ "$WIZARD"

# T5: table header contains Lines column
check "table header contains Lines" \
  bash -c 'grep -A30 "_skill_impact_table()" "$1" | grep -qi "lines"' _ "$WIZARD"

# T6: table header contains Tokens column
check "table header contains Tokens" \
  bash -c 'grep -A30 "_skill_impact_table()" "$1" | grep -qi "tokens"' _ "$WIZARD"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
