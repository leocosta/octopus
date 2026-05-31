#!/usr/bin/env bash
# tests/test_knowledge_briefing.sh — knowledge-briefing engine (RM-109).
# Behavioral fixtures for the deterministic core + structural checks on the
# SKILL.md (mirrors tests/test_knowledge_hygiene.sh).
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
export KR_USER_YML="${TMPDIR:-/tmp}/kb-no-user-config-$$.yml"
export KB_STATE_DIR="${TMPDIR:-/tmp}/kb-state-$$"   # isolate watermark from real user config

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Run `octopus briefing <args>` from inside a fixture repo.
briefing() {
  local dir="$1"; shift
  ( cd "$dir" && env -u OCTOPUS_MEMORY_DIR -u CONSIGLIERE_WORKSPACE \
      bash "$OCTOPUS_DIR/cli/octopus.sh" briefing "$@" )
}

make_fixture() { local d; d="$(mktemp -d)"; mkdir -p "$d/docs" "$d/knowledge"; echo "$d"; }

trap 'rm -rf "${FIXTURES[@]}" "$KB_STATE_DIR"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# Task 1 — `octopus briefing` runs over the resolved roots
# ---------------------------------------------------------------------------
REPO1="$(make_fixture)"; FIXTURES+=("$REPO1")

t1_runs_zero_exit()  { briefing "$REPO1" >/dev/null 2>&1; }
t1_names_docs_root() { local o; o="$(briefing "$REPO1" 2>/dev/null)"; grep -q 'docs' <<<"$o"; }

check "briefing runs with zero exit"  t1_runs_zero_exit
check "briefing names the docs root"  t1_names_docs_root

# ---------------------------------------------------------------------------
# Task 2 — watermark (per-root, user-scoped; never written into the repo)
# ---------------------------------------------------------------------------
kb_call() { local dir="$1"; shift; ( cd "$dir" && source "$OCTOPUS_DIR/cli/lib/knowledge-briefing.sh" && "$@" ); }

REPO2="$(make_fixture)"; FIXTURES+=("$REPO2")

t2_watermark_roundtrip() {
  kb_call "$REPO2" kb_watermark_set docs 1700000000
  [[ "$(kb_call "$REPO2" kb_watermark_get docs)" == "1700000000" ]]
}
t2_never_writes_repo() {
  kb_call "$REPO2" kb_watermark_set docs 1700000000
  [[ ! -e "$REPO2/.octopus" ]]
}

check "watermark: read/write roundtrip"        t2_watermark_roundtrip
check "watermark: never written into the repo"  t2_never_writes_repo

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
