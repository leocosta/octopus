#!/usr/bin/env bash
# tests/test_knowledge_root.sh — Unit/contract tests for the knowledge-root
# registry (RM-106). Exercises the `octopus kr` subcommand end-to-end.
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

# Isolate from the developer's real user config: point KR_USER_YML at a
# nonexistent file by default; individual tests override it explicitly.
export KR_USER_YML="${TMPDIR:-/tmp}/kr-no-user-config-$$.yml"

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

# ---------------------------------------------------------------------------
# Task 2 — kr meta applies override precedence (built-in < project < user)
# ---------------------------------------------------------------------------
REPO2="$(make_fixture)"; FIXTURES+=("$REPO2")
USER_YML2="$(mktemp)"; FIXTURES+=("$USER_YML2")
cat >"$REPO2/.octopus.yml" <<'YML'
knowledge_roots:
  docs:
    staleness_days: 60
YML
cat >"$USER_YML2" <<'YML'
knowledge_roots:
  docs:
    staleness_days: 45
YML

t2_user_overrides_project() {
  [[ "$(KR_USER_YML="$USER_YML2" kr "$REPO2" meta docs staleness_days)" == "45" ]]
}
t2_untouched_field_falls_back_to_default() {
  [[ "$(KR_USER_YML="$USER_YML2" kr "$REPO2" meta docs link_convention)" == "relative" ]]
}

check "kr meta: user override wins over project and default"  t2_user_overrides_project
check "kr meta: untouched field falls back to default"        t2_untouched_field_falls_back_to_default

# ---------------------------------------------------------------------------
# Task 3 — load-time guard (ADR-009): reject a `path:` override for a per-user
# root in the PROJECT manifest; allow scalar overrides there.
# ---------------------------------------------------------------------------
REPO3="$(make_fixture)"; FIXTURES+=("$REPO3")
printf 'knowledge_roots:\n  consigliere:\n    path: /home/x/private-ws\n' >"$REPO3/.octopus.yml"

REPO3B="$(make_fixture)"; FIXTURES+=("$REPO3B")
printf 'knowledge_roots:\n  consigliere:\n    staleness_days: 50\n' >"$REPO3B/.octopus.yml"

t3_rejects_private_path() {
  local out rc
  out="$(kr "$REPO3" list 2>&1)"; rc=$?
  [[ $rc -ne 0 ]] && grep -q "path override not allowed in project .octopus.yml: consigliere" <<<"$out"
}
t3_allows_scalar_override() { kr "$REPO3B" list >/dev/null 2>&1; }

check "kr guard: rejects per-user path override in project manifest"  t3_rejects_private_path
check "kr guard: allows scalar override for per-user root in project"  t3_allows_scalar_override

# ---------------------------------------------------------------------------
# Task 4 — kr nodes (excludes archive dir) + kr archive
# ---------------------------------------------------------------------------
REPO4="$(make_fixture)"; FIXTURES+=("$REPO4")
mkdir -p "$REPO4/docs/plans/archive"
: >"$REPO4/docs/a.md"
: >"$REPO4/docs/plans/archive/old.md"

t4_nodes_includes_active()    { kr "$REPO4" nodes docs | grep -q '/docs/a\.md$'; }
t4_nodes_excludes_archive()   { ! kr "$REPO4" nodes docs | grep -q 'archive/old\.md'; }
t4_archive_docs_path()        { [[ "$(kr "$REPO4" archive docs)" == "$REPO4/docs/plans/archive/" ]]; }
t4_archive_standards_empty()  { [[ -z "$(kr "$REPO4" archive standards)" ]]; }

check "kr nodes: includes active node"            t4_nodes_includes_active
check "kr nodes: excludes archived node"          t4_nodes_excludes_archive
check "kr archive: returns root-relative path"    t4_archive_docs_path
check "kr archive: empty when root declares none"  t4_archive_standards_empty

# ---------------------------------------------------------------------------
# Task 5 — kr links: one resolver per link_convention
# ---------------------------------------------------------------------------
REPO5="$(make_fixture)"; FIXTURES+=("$REPO5")
printf '[x](./b.md)\n' >"$REPO5/docs/a.md"; : >"$REPO5/docs/b.md"
: >"$REPO5/knowledge/x.md"

MEM5="$(mktemp -d)"; FIXTURES+=("$MEM5")
printf 'see [[other]]\n' >"$MEM5/note.md"; : >"$MEM5/other.md"

WS5="$(mktemp -d)"; FIXTURES+=("$WS5")
mkdir -p "$WS5/projects" "$WS5/contexts/payments"
printf '[ctx](../contexts/payments/state.md)\n' >"$WS5/projects/p.md"; : >"$WS5/contexts/payments/state.md"

t5_relative() { kr "$REPO5" links docs "$REPO5/docs/a.md" | grep -q '/docs/b\.md$'; }
t5_none()     { [[ -z "$(kr "$REPO5" links standards "$REPO5/knowledge/x.md")" ]]; }
t5_wikilink() {
  ( cd "$REPO5" && env -u CONSIGLIERE_WORKSPACE OCTOPUS_MEMORY_DIR="$MEM5" \
      bash "$OCTOPUS_DIR/cli/octopus.sh" kr links memory "$MEM5/note.md" ) | grep -q "^$MEM5/other\.md$"
}
t5_fanout() {
  ( cd "$REPO5" && env -u OCTOPUS_MEMORY_DIR CONSIGLIERE_WORKSPACE="$WS5" \
      bash "$OCTOPUS_DIR/cli/octopus.sh" kr links consigliere "$WS5/projects/p.md" ) | grep -q '/contexts/payments/state\.md$'
}

check "kr links: relative resolver"   t5_relative
check "kr links: none resolver empty"  t5_none
check "kr links: wikilink resolver"    t5_wikilink
check "kr links: fanout resolver"      t5_fanout

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
