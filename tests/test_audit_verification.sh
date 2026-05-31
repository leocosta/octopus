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

# ---------------------------------------------------------------------------
# Task 3 — unresolved-reference: a missing-file import queues even if a run ran
# ---------------------------------------------------------------------------
REPO3="$(make_git_repo)"; FIXTURES+=("$REPO3")

t3_flags_missing_import() {
  printf "import x from './missing'\nexport const c = x\n" >"$REPO3/src/seed.ts"
  rm -rf "$REPO3/.octopus"
  run_hook "$REPO3" "$TR_RUN"   # a run was found, yet the missing import must still queue
  local p; p="$(proposals_of "$REPO3")"
  [[ -n "$p" ]] && grep -q 'unresolved-reference' "$p" && grep -q 'missing' "$p"
}
t3_no_flag_when_import_resolves() {
  local r; r="$(make_git_repo)"; FIXTURES+=("$r")
  : >"$r/src/dep.ts"
  printf "import x from './dep'\nexport const d = x\n" >"$r/src/seed.ts"
  rm -rf "$r/.octopus"
  run_hook "$r" "$TR_RUN"   # run found + import resolves → suppressed
  [[ -z "$(proposals_of "$r")" ]]
}

check "unresolved-ref: missing import queues even when a run ran"  t3_flags_missing_import
check "unresolved-ref: resolved import + run stays suppressed"      t3_no_flag_when_import_resolves

# ---------------------------------------------------------------------------
# Task 4 — registration: hooks.json + SKILL.md + command + bundle (structural)
# ---------------------------------------------------------------------------
SKILL="$OCTOPUS_DIR/skills/audit-verification/SKILL.md"

t4_hook_registered()  { grep -q 'verification-check' "$OCTOPUS_DIR/hooks/hooks.json"; }
t4_skill_frontmatter() { [[ -f "$SKILL" ]] && head -5 "$SKILL" | grep -q '^name: audit-verification$'; }
t4_skill_findings() {
  grep -q 'unverified-completion-claim' "$SKILL" && grep -q 'unresolved-reference' "$SKILL"
}
t4_skill_signal_only() { grep -qiE 'signal.only|never block' "$SKILL"; }
t4_skill_cheap_tier()  { grep -qiE 'cheap|haiku|fastest' "$SKILL"; }
t4_skill_review_path() { grep -q 'review-proposals' "$SKILL"; }
t4_registered_in_bundle() { grep -rqE '^ *- audit-verification( |$)' "$OCTOPUS_DIR/bundles"; }

check "registration: hook in hooks.json"        t4_hook_registered
check "skill: valid frontmatter"                 t4_skill_frontmatter
check "skill: documents both findings"           t4_skill_findings
check "skill: signal-only / never blocks"        t4_skill_signal_only
check "skill: marks judgment cheap-tier"         t4_skill_cheap_tier
check "skill: routes via review-proposals"       t4_skill_review_path
check "skill: registered in a bundle"            t4_registered_in_bundle

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
