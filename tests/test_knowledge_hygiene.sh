#!/usr/bin/env bash
# tests/test_knowledge_hygiene.sh — knowledge-hygiene engine (RM-107).
# Behavioral fixtures for the deterministic core + structural checks on the
# SKILL.md (mirrors tests/test_plan_backlog_hygiene.sh).
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
export KR_USER_YML="${TMPDIR:-/tmp}/kh-no-user-config-$$.yml"

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Run `octopus hygiene <args>` from inside a fixture repo.
hygiene() {
  local dir="$1"; shift
  ( cd "$dir" && env -u OCTOPUS_MEMORY_DIR -u CONSIGLIERE_WORKSPACE \
      bash "$OCTOPUS_DIR/cli/octopus.sh" hygiene "$@" )
}

make_fixture() { local d; d="$(mktemp -d)"; mkdir -p "$d/docs" "$d/knowledge"; echo "$d"; }

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# Task 1 — `octopus hygiene` runs over the resolved roots
# ---------------------------------------------------------------------------
REPO1="$(make_fixture)"; FIXTURES+=("$REPO1")

t1_runs_zero_exit() { hygiene "$REPO1" >/dev/null 2>&1; }
t1_names_docs_root() { hygiene "$REPO1" 2>/dev/null | grep -q 'docs'; }

check "hygiene runs with zero exit"      t1_runs_zero_exit
check "hygiene names the docs root"      t1_names_docs_root

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
