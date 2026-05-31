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
# Task 2 — ks_entities extractor: structural + language-neutral only
# ([[mentions]] + `code` spans). Free-text entities are the SKILL.md's (LLM) job.
# ---------------------------------------------------------------------------
ks_entities_of() { ( source "$OCTOPUS_DIR/cli/lib/knowledge-synthesize.sh" && ks_entities "$1" ); }

REPO2="$(make_fixture)"; FIXTURES+=("$REPO2")
# pt-br node: a wikilink with accents the core must keep verbatim (no ASCII regex)
printf 'sobre [[Política Fiscal]] e `kr_load`. O Gestor de Estoque cuida disso.\n' >"$REPO2/docs/n.md"

t2_extracts_accented_wikilink() { grep -q 'Política Fiscal' <<<"$(ks_entities_of "$REPO2/docs/n.md")"; }
t2_extracts_code_span()         { grep -q 'kr_load' <<<"$(ks_entities_of "$REPO2/docs/n.md")"; }
t2_ignores_free_text()          { ! grep -q 'Gestor de Estoque' <<<"$(ks_entities_of "$REPO2/docs/n.md")"; }

check "entities: extracts accented wikilink (pt-br)"  t2_extracts_accented_wikilink
check "entities: extracts code span"                  t2_extracts_code_span
check "entities: leaves free-text to the LLM layer"   t2_ignores_free_text

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

# ---------------------------------------------------------------------------
# Task 4 — co-mention signal (entity in >=2 nodes with no home node)
# ---------------------------------------------------------------------------
REPO4="$(make_fixture)"; FIXTURES+=("$REPO4")
printf 'about [[Fiscal Engine]]\n' >"$REPO4/docs/x.md"
printf 'also [[Fiscal Engine]]\n' >"$REPO4/docs/y.md"

t4_co_mention() {
  local o; o="$(synthesize "$REPO4" --root docs 2>/dev/null)"
  grep -q 'co-mention|docs|Fiscal Engine||2' <<<"$o"
}

check "co-mention: recurring entity with no home node"  t4_co_mention

# ---------------------------------------------------------------------------
# Task 5 — relevant signal (--node lexical overlap, top-N)
# ---------------------------------------------------------------------------
REPO5="$(make_fixture)"; FIXTURES+=("$REPO5")
printf 'about [[Stock Ledger]] and [[Reorder Policy]]\n' >"$REPO5/docs/focus.md"
printf 'the [[Stock Ledger]] design\n' >"$REPO5/docs/match.md"
: >"$REPO5/docs/unrelated.md"

t5_relevant_ranks_match() {
  local o; o="$(synthesize "$REPO5" --root docs --node "$REPO5/docs/focus.md" 2>/dev/null)"
  grep -q "relevant|docs|$REPO5/docs/focus.md|$REPO5/docs/match.md" <<<"$o"
}
t5_relevant_skips_unrelated() {
  local o; o="$(synthesize "$REPO5" --root docs --node "$REPO5/docs/focus.md" 2>/dev/null)"
  ! grep -q "unrelated.md" <<<"$o"
}

check "relevant: ranks node sharing an entity"  t5_relevant_ranks_match
check "relevant: skips node with no overlap"     t5_relevant_skips_unrelated

# ---------------------------------------------------------------------------
# Task 6 — --fix seeds a link only for an exact single-target mention
# ---------------------------------------------------------------------------
REPO6="$(make_git_fixture)"; FIXTURES+=("$REPO6")
printf 'mentions [[Stock Ledger]]\n' >"$REPO6/docs/note.md"
: >"$REPO6/docs/Stock Ledger.md"
( cd "$REPO6" && git add -A && git commit -qm seed )

t6_fix_seeds_link() {
  synthesize "$REPO6" --root docs --fix >/dev/null 2>&1
  grep -q 'Stock Ledger.md' "$REPO6/docs/note.md"
}

check "fix: seeds link for exact single-target mention"  t6_fix_seeds_link

# ---------------------------------------------------------------------------
# Task 7 — SKILL.md wrapper documents signals, invocation, and judgment
# (structural, mirrors tests/test_knowledge_hygiene.sh)
# ---------------------------------------------------------------------------
SKILL="$OCTOPUS_DIR/skills/knowledge-synthesize/SKILL.md"

t7_skill_frontmatter() { [[ -f "$SKILL" ]] && head -5 "$SKILL" | grep -q '^name: knowledge-synthesize$'; }
t7_documents_invocation() {
  grep -q '^## Invocation$' "$SKILL" || return 1
  local f; for f in --root --node --fix; do grep -q -- "$f" "$SKILL" || return 1; done
}
t7_documents_signals() {
  local c; for c in shared-target co-mention relevant contradiction; do grep -q "$c" "$SKILL" || return 1; done
}
t7_delegates_to_kr()    { grep -q 'octopus kr' "$SKILL"; }
t7_report_template()    { [[ -f "$OCTOPUS_DIR/skills/knowledge-synthesize/templates/report.md" ]]; }
t7_registered_in_bundle() { grep -rqx ' *- knowledge-synthesize' "$OCTOPUS_DIR/bundles"; }

check "skill: valid frontmatter"             t7_skill_frontmatter
check "skill: documents invocation + flags"   t7_documents_invocation
check "skill: documents signals + judgment"   t7_documents_signals
check "skill: delegates mechanics to kr"      t7_delegates_to_kr
check "skill: report template present"        t7_report_template
check "skill: registered in a bundle"         t7_registered_in_bundle

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
