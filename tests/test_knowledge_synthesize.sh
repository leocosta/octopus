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

# ---------------------------------------------------------------------------
# Task 2 — ks_entities extractor (wikilink + capitalized phrase + code span)
# ---------------------------------------------------------------------------
ks_entities_of() { ( source "$OCTOPUS_DIR/cli/lib/knowledge-synthesize.sh" && ks_entities "$1" ); }

REPO2="$(make_fixture)"; FIXTURES+=("$REPO2")
printf 'see [[Payments Gateway]] and `kr_load`. The Tech Manager owns it.\n' >"$REPO2/docs/n.md"

t2_extracts_wikilink() { grep -q 'Payments Gateway' <<<"$(ks_entities_of "$REPO2/docs/n.md")"; }
t2_extracts_code_span() { grep -q 'kr_load' <<<"$(ks_entities_of "$REPO2/docs/n.md")"; }
t2_extracts_capitalized_phrase() { grep -q 'Tech Manager' <<<"$(ks_entities_of "$REPO2/docs/n.md")"; }

check "entities: extracts wikilink"            t2_extracts_wikilink
check "entities: extracts code span"           t2_extracts_code_span
check "entities: extracts capitalized phrase"  t2_extracts_capitalized_phrase

# ---------------------------------------------------------------------------
# Task 3 — shared-target signal (two nodes linking the same third)
# ---------------------------------------------------------------------------
REPO3="$(make_fixture)"; FIXTURES+=("$REPO3")
printf '[t](./t.md)\n' >"$REPO3/docs/a.md"
printf '[t](./t.md)\n' >"$REPO3/docs/b.md"
: >"$REPO3/docs/t.md"

t3_shared_target() {
  local o; o="$(synthesize "$REPO3" --root docs 2>/dev/null)"
  grep -q "shared-target|docs|$REPO3/docs/a.md|$REPO3/docs/b.md|$REPO3/docs/t.md|1" <<<"$o"
}

check "shared-target: pairs nodes linking the same third"  t3_shared_target

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
