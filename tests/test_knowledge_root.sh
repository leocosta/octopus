#!/usr/bin/env bash
# tests/test_knowledge_root.sh — Unit/contract tests for the knowledge-root
# registry (RM-106). Exercises the `octopus kr` subcommand end-to-end.
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
check_not() {
  local desc="$1"; shift
  if ! "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Run `octopus kr <args>` from inside a fixture repo, with per-user roots unset
# so only repo-relative built-ins (docs, standards) resolve.
kr() {
  local dir="$1"; shift
  ( cd "$dir" && env -u OCTOPUS_MEMORY_DIR -u CONSIGLIERE_WORKSPACE \
      bash "$OCTOPUS_DIR/cli/octopus.sh" kr "$@" )
}

make_fixture() { local d; d="$(mktemp -d)"; mkdir -p "$d/docs" "$d/knowledge"; echo "$d"; }

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# Task 1 — kr list shows present built-in roots, omits unresolved ones
# ---------------------------------------------------------------------------
REPO1="$(make_fixture)"; FIXTURES+=("$REPO1")

t1_list_has_docs()           { kr "$REPO1" list | grep -qx docs; }
t1_list_has_standards()      { kr "$REPO1" list | grep -qx standards; }
t1_list_omits_consigliere()  { kr "$REPO1" list | grep -qx consigliere; }

check     "kr list includes docs"                 t1_list_has_docs
check     "kr list includes standards"            t1_list_has_standards
check_not "kr list omits unresolved consigliere"  t1_list_omits_consigliere

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
