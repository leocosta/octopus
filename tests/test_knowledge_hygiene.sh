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

# Capture output fully before grepping — `hygiene | grep -q` would SIGPIPE the
# producer under pipefail (grep -q exits on first match).
t1_runs_zero_exit() { hygiene "$REPO1" >/dev/null 2>&1; }
t1_names_docs_root() { local o; o="$(hygiene "$REPO1" 2>/dev/null)"; grep -q 'docs' <<<"$o"; }

check "hygiene runs with zero exit"      t1_runs_zero_exit
check "hygiene names the docs root"      t1_names_docs_root

# ---------------------------------------------------------------------------
# Task 2 — staleness check (cascade: frontmatter updated: → git → mtime)
# ---------------------------------------------------------------------------
REPO2="$(make_fixture)"; FIXTURES+=("$REPO2")
printf -- '---\nupdated: 2000-01-01\n---\n# old\n' >"$REPO2/docs/old.md"

t2_flags_stale_by_frontmatter() {
  local o; o="$(hygiene "$REPO2" --root docs 2>/dev/null)"
  grep -q "warn|docs|staleness|$REPO2/docs/old.md" <<<"$o"
}

check "staleness: flags node stale by frontmatter date"  t2_flags_stale_by_frontmatter

# ---------------------------------------------------------------------------
# Task 3 — broken-link check
# ---------------------------------------------------------------------------
REPO3="$(make_fixture)"; FIXTURES+=("$REPO3")
printf '[gone](./missing.md)\n' >"$REPO3/docs/a.md"

t3_flags_broken_link() {
  local o; o="$(hygiene "$REPO3" --root docs 2>/dev/null)"
  grep -q "warn|docs|broken-link|$REPO3/docs/a.md" <<<"$o"
}

check "broken-link: flags missing link target"  t3_flags_broken_link

# ---------------------------------------------------------------------------
# Task 4 — orphan check (entry patterns + allowlist excluded)
# ---------------------------------------------------------------------------
REPO4="$(make_fixture)"; FIXTURES+=("$REPO4")
: >"$REPO4/docs/hub.md"                                   # no inbound → orphan
: >"$REPO4/docs/README.md"                                # entry pattern → excluded
printf '[b](./b.md)\n' >"$REPO4/docs/a.md"; : >"$REPO4/docs/b.md"   # b has inbound

t4_flags_orphan() {
  local o; o="$(hygiene "$REPO4" --root docs 2>/dev/null)"
  grep -q "info|docs|orphan|$REPO4/docs/hub.md" <<<"$o"
}
t4_excludes_entry_node() {
  local o; o="$(hygiene "$REPO4" --root docs 2>/dev/null)"
  ! grep -q "orphan|$REPO4/docs/README.md" <<<"$o"
}

check "orphan: flags node with no inbound links"  t4_flags_orphan
check "orphan: excludes entry-pattern node"       t4_excludes_entry_node

# ---------------------------------------------------------------------------
# Task 5 — archive-drift check (terminal frontmatter status, outside archive)
# ---------------------------------------------------------------------------
REPO5="$(make_fixture)"; FIXTURES+=("$REPO5")
printf -- '---\nstatus: done\n---\n# finished\n' >"$REPO5/docs/finished.md"

t5_flags_archive_drift() {
  local o; o="$(hygiene "$REPO5" --root docs 2>/dev/null)"
  grep -q "info|docs|archive-drift|$REPO5/docs/finished.md" <<<"$o"
}

check "archive-drift: flags concluded node outside archive"  t5_flags_archive_drift

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
