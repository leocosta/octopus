#!/usr/bin/env bash
# tests/test_audit_verification.sh — verification-check Stop hook (RM-111).
# Behavioral fixtures for the deterministic, zero-LLM hook + structural checks
# on the SKILL.md. Grep/exit-code based, per project convention.
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$OCTOPUS_DIR/hooks/stop/verification-check.sh"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# Run the Stop hook inside a git fixture, feeding the Stop JSON on stdin.
# Args: <repo> <transcript-path-or-empty>
run_hook() {
  local repo="$1" transcript="${2:-}"
  ( cd "$repo" && printf '{"transcript_path":"%s"}' "$transcript" \
      | bash "$HOOK" >/dev/null 2>&1 )
}

make_git_repo() {
  local d; d="$(mktemp -d)"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t
    mkdir -p src docs && : >src/seed.ts && : >docs/seed.md && git add -A && git commit -qm seed )
  echo "$d"
}
proposals_of() { find "$1/.octopus/proposals" -name '*-verification.md' 2>/dev/null; }

trap 'rm -rf "${FIXTURES[@]}"' EXIT
FIXTURES=()

# ---------------------------------------------------------------------------
# Task 1 — code-diff gate + conditional proposal; soft-skip docs-only / clean
# ---------------------------------------------------------------------------
REPO1="$(make_git_repo)"; FIXTURES+=("$REPO1")

t1_queues_on_code_diff() {
  printf 'export const x = 1\n' >"$REPO1/src/seed.ts"   # code change, uncommitted
  run_hook "$REPO1"
  [[ -n "$(proposals_of "$REPO1")" ]]
}
t1_skips_docs_only() {
  local r; r="$(make_git_repo)"; FIXTURES+=("$r")
  printf 'more docs\n' >"$r/docs/seed.md"               # docs-only change
  run_hook "$r"
  [[ -z "$(proposals_of "$r")" ]]
}
t1_skips_clean_tree() {
  local r; r="$(make_git_repo)"; FIXTURES+=("$r")       # no change
  run_hook "$r"
  [[ -z "$(proposals_of "$r")" ]]
}
t1_never_blocks() {
  printf 'export const y = 2\n' >"$REPO1/src/seed.ts"
  run_hook "$REPO1"   # exit code must be 0
}

check "hook: queues a proposal on a code diff"   t1_queues_on_code_diff
check "hook: skips a docs-only diff"             t1_skips_docs_only
check "hook: skips a clean tree"                 t1_skips_clean_tree
check "hook: never blocks (exit 0)"              t1_never_blocks

# ---------------------------------------------------------------------------
# Task 2 — run-evidence scan: a run command in the transcript suppresses the
# proposal; no run (or no transcript) queues it.
# ---------------------------------------------------------------------------
REPO2="$(make_git_repo)"; FIXTURES+=("$REPO2")
TR_RUN="$(mktemp)"; FIXTURES+=("$TR_RUN"); echo 'I ran `npm test` and `tsc --noEmit` — all green' >"$TR_RUN"
TR_NORUN="$(mktemp)"; FIXTURES+=("$TR_NORUN"); echo 'edited the service and called it done' >"$TR_NORUN"

t2_suppresses_when_run_found() {
  printf 'export const a = 1\n' >"$REPO2/src/seed.ts"
  rm -rf "$REPO2/.octopus"
  run_hook "$REPO2" "$TR_RUN"
  [[ -z "$(proposals_of "$REPO2")" ]]
}
t2_queues_when_no_run() {
  printf 'export const b = 2\n' >"$REPO2/src/seed.ts"
  rm -rf "$REPO2/.octopus"
  run_hook "$REPO2" "$TR_NORUN"
  [[ -n "$(proposals_of "$REPO2")" ]]
}

check "run-scan: suppresses proposal when a run command is in the transcript"  t2_suppresses_when_run_found
check "run-scan: queues when no run command is found"                          t2_queues_when_no_run

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
