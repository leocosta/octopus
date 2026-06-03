#!/usr/bin/env bash
# tests/test_cli_registry.sh
# RM-113 — the CLI command registry. cli/octopus.sh generates its help from
# cli/lib/commands.default and rejects any name that is not registered, even
# when a cli/lib/<name>.sh file exists (helper/implementation libs are not
# commands and must not be silently sourced as no-ops). Grep/exit-code
# assertions, per project convention.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$SCRIPT_DIR/cli/octopus.sh"
REGISTRY="$SCRIPT_DIR/cli/lib/commands.default"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# --- the registry file -----------------------------------------------------
check "registry file exists" test -f "$REGISTRY"
check "registry lists a known command (release)" grep -qE '^release\|' "$REGISTRY"

# --- integrity: every registered command has a backing lib -----------------
registry_integrity() {
  local name _rest
  while IFS='|' read -r name _rest; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    [[ -f "$SCRIPT_DIR/cli/lib/$name.sh" ]] || { echo "missing lib for: $name"; return 1; }
  done < "$REGISTRY"
}
check "every registered command has a cli/lib/<name>.sh" registry_integrity

# --- generated help lists registered commands ------------------------------
USAGE="$("$CLI" 2>&1 || true)"
check "bare invocation lists 'release'" grep -q "release" <<<"$USAGE"
check "bare invocation lists 'ask'"     grep -q "ask"     <<<"$USAGE"
check "bare invocation lists 'lens'"    grep -q "lens"    <<<"$USAGE"

# --- THE GUARD: a lib file that is not a registered command is rejected -----
reject() {  # $1 = name whose cli/lib/<name>.sh exists but is not a command
  local out rc
  out="$("$CLI" "$1" 2>&1)"; rc=$?
  [[ $rc -ne 0 ]] && grep -qi "unknown command" <<<"$out"
}
check "helper lib 'ui' is rejected (not a command)"      reject ui
check "helper lib 'audit-map' is rejected"               reject audit-map
check "impl lib 'knowledge-hygiene' is rejected"         reject knowledge-hygiene
check "impl lib 'consigliere-lens' is rejected"          reject consigliere-lens
check "a bare unknown name is rejected"                  reject definitely-not-a-command

# --- help is a first-class, zero-exit command ------------------------------
check "'help' prints usage and exits 0" bash -c "'$CLI' help >/dev/null 2>&1"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
