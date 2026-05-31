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

# ---------------------------------------------------------------------------
# Task 3 — change-delta (nodes updated after the watermark)
# ---------------------------------------------------------------------------
REPO3="$(make_fixture)"; FIXTURES+=("$REPO3")
printf -- '---\nupdated: 2030-01-01\n---\n# fresh\n' >"$REPO3/docs/fresh.md"
: >"$REPO3/docs/old.md"; touch -d '2000-01-01' "$REPO3/docs/old.md"
kb_call "$REPO3" kb_watermark_set docs "$(date -d '2020-01-01' +%s)"

# fresh.md is dated in the future, so it stays "changed" regardless of how the
# watermark advances — keeps the assertion robust once --daily advances it (t5).
t3_flags_changed() {
  local o; o="$(briefing "$REPO3" --root docs 2>/dev/null)"
  grep -q "changed|docs|$REPO3/docs/fresh.md" <<<"$o"
}
t3_skips_old() {
  local o; o="$(briefing "$REPO3" --root docs 2>/dev/null)"
  ! grep -q "changed|docs|$REPO3/docs/old.md" <<<"$o"
}

check "change-delta: flags node updated after watermark"  t3_flags_changed
check "change-delta: skips node older than watermark"     t3_skips_old

# ---------------------------------------------------------------------------
# Task 4 — compose attention (hygiene warn-tier) + weekly connections
# ---------------------------------------------------------------------------
REPO4="$(make_fixture)"; FIXTURES+=("$REPO4")
printf -- '---\nupdated: 2000-01-01\n---\n# stale\n' >"$REPO4/docs/stale.md"

t4_attention_folds_hygiene() {
  local o; o="$(briefing "$REPO4" --root docs 2>/dev/null)"
  grep -q "attention|docs|$REPO4/docs/stale.md" <<<"$o"
}

check "attention: folds hygiene warn-tier"  t4_attention_folds_hygiene

# ---------------------------------------------------------------------------
# Task 5 — --daily advances the watermark; --weekly leaves it untouched
# ---------------------------------------------------------------------------
REPO5="$(make_fixture)"; FIXTURES+=("$REPO5")
: >"$REPO5/docs/recent.md"   # mtime ~now, no future frontmatter

t5_daily_advances_watermark() {
  briefing "$REPO5" --root docs --daily >/dev/null 2>&1          # 1st run: within 7d → changed; advances
  local second; second="$(briefing "$REPO5" --root docs --daily 2>/dev/null)"
  ! grep -q "changed|docs|$REPO5/docs/recent.md" <<<"$second"    # 2nd run: nothing new
}
t5_weekly_does_not_advance() {
  kb_call "$REPO5" kb_watermark_set docs 555
  briefing "$REPO5" --root docs --weekly >/dev/null 2>&1
  [[ "$(kb_call "$REPO5" kb_watermark_get docs)" == "555" ]]
}

check "daily: advances the watermark"        t5_daily_advances_watermark
check "weekly: leaves the watermark untouched"  t5_weekly_does_not_advance

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
