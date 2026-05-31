#!/usr/bin/env bash
# tests/test_check_docs.sh — site/scripts/check-docs.sh (site-docs-overhaul).
# Deterministic page guard: implementation leakage + unfinished published TODO.
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$OCTOPUS_DIR/site/scripts/check-docs.sh"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

run() { CHECK_DOCS_ROOT="$1" bash "$CHECK" "${2:-}"; }

make_docs() {
  local d; d="$(mktemp -d)"
  printf -- '---\ntitle: clean\n---\nA tidy page.\n' >"$d/clean.mdx"
  printf -- '---\ntitle: leak\n---\nShipped in RM-088, see Cluster 19 (#123).\n' >"$d/leak.mdx"
  printf -- '---\ntitle: draft\ndraft: true\n---\nWork in progress, RM-088.\n' >"$d/draft-leak.mdx"
  printf -- '---\ntitle: todo\n---\n<!-- TODO: write the rationale -->\n' >"$d/todo.mdx"
  echo "$d"
}

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()
D="$(make_docs)"; FIXTURES+=("$D")

# Capture output before grepping — `run | grep -q` SIGPIPEs the script under
# pipefail (grep -q exits on first match).
# --- leakage ---------------------------------------------------------------
t_fails_on_leak()   { ! run "$D" >/dev/null 2>&1; }                 # nonzero exit
t_names_leak_page() { local o; o="$(run "$D" 2>&1)"; grep -q 'leak.mdx' <<<"$o"; }
t_excludes_draft()  { local o; o="$(run "$D" 2>&1)"; ! grep -q 'draft-leak.mdx' <<<"$o"; }
# --- no-published-TODO -----------------------------------------------------
t_names_todo_page() { local o; o="$(run "$D" 2>&1)"; grep -q 'todo.mdx' <<<"$o"; }
# --- clean fixture passes --------------------------------------------------
t_clean_passes() {
  local c; c="$(mktemp -d)"; FIXTURES+=("$c")
  printf -- '---\ntitle: ok\n---\nNothing to flag.\n' >"$c/ok.mdx"
  run "$c" >/dev/null 2>&1
}
# --- --report mode never fails --------------------------------------------
t_report_mode_exit_zero() { run "$D" --report >/dev/null 2>&1; }

check "check: fails on implementation leakage"        t_fails_on_leak
check "check: names the leaking page"                 t_names_leak_page
check "check: excludes draft pages from leakage"      t_excludes_draft
check "check: flags a published TODO rationale"       t_names_todo_page
check "check: a clean docs tree passes"               t_clean_passes
check "check: --report lists but exits 0"             t_report_mode_exit_zero

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
