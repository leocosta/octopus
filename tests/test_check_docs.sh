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

# An empty repo root so the completeness check finds no artifacts to require —
# the leakage/TODO tests only exercise page content, not completeness.
EMPTY_REPO="$(mktemp -d)"
run() { CHECK_DOCS_ROOT="$1" CHECK_REPO_ROOT="${3:-$EMPTY_REPO}" bash "$CHECK" "${2:-}"; }

make_docs() {
  local d; d="$(mktemp -d)"
  printf -- '---\ntitle: clean\n---\nA tidy page.\n' >"$d/clean.mdx"
  printf -- '---\ntitle: leak\n---\nShipped in RM-088, see Cluster 19 (#123).\n' >"$d/leak.mdx"
  printf -- '---\ntitle: draft\ndraft: true\n---\nWork in progress, RM-088.\n' >"$d/draft-leak.mdx"
  printf -- '---\ntitle: todo\n---\n{/* TODO: write the rationale */}\n' >"$d/todo.mdx"
  echo "$d"
}

trap 'rm -rf "${FIXTURES[@]}" "$EMPTY_REPO"' EXIT
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

# --- completeness: artifact without a page is flagged ----------------------
make_artifact_repo() {  # a repo with one skill (SKILL.md)
  local r; r="$(mktemp -d)"; mkdir -p "$r/skills/demo/"
  printf -- '---\nname: demo\ndescription: x\n---\n' >"$r/skills/demo/SKILL.md"
  echo "$r"
}
AREPO="$(make_artifact_repo)"; FIXTURES+=("$AREPO")
t_completeness_flags_missing() {
  local c; c="$(mktemp -d)"; FIXTURES+=("$c")     # docs with no skill page
  local o; o="$(run "$c" '' "$AREPO" 2>&1)"
  grep -q 'MISSING: skills/demo.mdx' <<<"$o" && grep -q 'MISSING: pt-br/skills/demo.mdx' <<<"$o"
}
t_completeness_passes_when_present() {
  local c; c="$(mktemp -d)"; FIXTURES+=("$c")
  mkdir -p "$c/skills" "$c/pt-br/skills"
  printf -- '---\ntitle: demo\ndescription: x\n---\nok\n' >"$c/skills/demo.mdx"
  printf -- '---\ntitle: demo\ndescription: x\n---\nok\n' >"$c/pt-br/skills/demo.mdx"
  run "$c" '' "$AREPO" >/dev/null 2>&1
}

check "check: fails on implementation leakage"        t_fails_on_leak
check "check: names the leaking page"                 t_names_leak_page
check "check: excludes draft pages from leakage"      t_excludes_draft
check "check: flags a published TODO rationale"       t_names_todo_page
check "check: a clean docs tree passes"               t_clean_passes
check "check: --report lists but exits 0"             t_report_mode_exit_zero
check "check: completeness flags a missing page"      t_completeness_flags_missing
check "check: completeness passes when EN+pt present" t_completeness_passes_when_present

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
