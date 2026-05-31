#!/usr/bin/env bash
# tests/test_knowledge_synthesize.sh — knowledge-synthesize engine (RM-108).
# Behavioral fixtures for the deterministic core + structural checks on the
# SKILL.md (mirrors tests/test_knowledge_hygiene.sh).
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
export KR_USER_YML="${TMPDIR:-/tmp}/ks-no-user-config-$$.yml"

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Run `octopus synthesize <args>` from inside a fixture repo.
synthesize() {
  local dir="$1"; shift
  ( cd "$dir" && env -u OCTOPUS_MEMORY_DIR -u CONSIGLIERE_WORKSPACE \
      bash "$OCTOPUS_DIR/cli/octopus.sh" synthesize "$@" )
}

make_fixture() { local d; d="$(mktemp -d)"; mkdir -p "$d/docs" "$d/knowledge"; echo "$d"; }
make_git_fixture() {
  local d; d="$(mktemp -d)"; mkdir -p "$d/docs"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t )
  echo "$d"
}

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# Task 1 — `octopus synthesize` runs over the resolved roots
# ---------------------------------------------------------------------------
REPO1="$(make_fixture)"; FIXTURES+=("$REPO1")

t1_runs_zero_exit()  { synthesize "$REPO1" >/dev/null 2>&1; }
t1_names_docs_root() { local o; o="$(synthesize "$REPO1" 2>/dev/null)"; grep -q 'docs' <<<"$o"; }

check "synthesize runs with zero exit"  t1_runs_zero_exit
check "synthesize names the docs root"  t1_names_docs_root

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
