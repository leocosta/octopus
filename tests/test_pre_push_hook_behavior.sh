#!/usr/bin/env bash
# tests/test_pre_push_hook_behavior.sh — Runtime behaviour of the pre-push audit hook.
#
# tests/test_post_merge_audit_hook.sh covers install/uninstall and the file's
# structure. This one runs the hook against real git fixtures, because the two
# defects it guards were both invisible to a structural check (RM-179):
#
#   - The hook ran only stage one of the two deterministic stages, so it
#     suggested audits that `octopus audit-scope` then reported as `skip`.
#   - It read its matches with `mapfile`, a bash 4.0 builtin. On a shell without
#     it the array stayed unset and `${#matched[@]}` under `set -u` aborted with
#     a non-zero status — which git reads as "reject the push", from a hook
#     documented as never blocking one.
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$OCTOPUS_DIR/hooks/git/pre-push-audit-suggest.sh"
PASS=0; FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; [[ -n "${2:-}" ]] && echo "      $2"; FAIL=$((FAIL + 1)); }

assert_contains() {
  local desc="$1" needle="$2" hay="$3"
  [[ "$hay" == *"$needle"* ]] && pass "$desc" || fail "$desc" "missing [$needle] in: ${hay:0:200}"
}

assert_not_contains() {
  local desc="$1" needle="$2" hay="$3"
  [[ "$hay" != *"$needle"* ]] && pass "$desc" || fail "$desc" "unexpected [$needle] in: ${hay:0:200}"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  [[ "$expected" == "$actual" ]] && pass "$desc" || fail "$desc" "expected [$expected] got [$actual]"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# stdin for a pre-push hook: "<local_ref> <local_sha> <remote_ref> <remote_sha>".
hook_stdin() { printf 'refs/heads/x %s refs/heads/x %s\n' "$1" "$2"; }

# --- fixture ---------------------------------------------------------------

REPO="$WORK/repo"
mkdir -p "$REPO/src"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t

echo "const x = 1;" > "$REPO/src/authMiddleware.ts"
echo "const y = 2;" > "$REPO/src/billing.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm base
BASE="$(git -C "$REPO" rev-parse HEAD)"

# authMiddleware.ts gets lines that hit audit-security's line_patterns.
# billing.ts gets a money-ish line that does NOT hit audit-money's — it matches
# the path token `billing` and nothing else, which is the stage-two case.
printf 'const token = req.headers.Authorization;\n' >> "$REPO/src/authMiddleware.ts"
printf 'const price = 10; // cents\n' >> "$REPO/src/billing.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm change
REF="$(git -C "$REPO" rev-parse HEAD)"

# --- never blocks the push -------------------------------------------------
# Every path through the hook must exit 0. This is its whole contract.

out="$(cd "$REPO" && hook_stdin "$REF" "$BASE" | bash "$HOOK" 2>&1)"; rc=$?
assert_eq "a matching diff exits 0" "0" "$rc"

out_empty="$(cd "$REPO" && hook_stdin "$BASE" "$BASE" | bash "$HOOK" 2>&1)"; rc=$?
assert_eq "an empty diff exits 0" "0" "$rc"
assert_eq "an empty diff prints nothing" "" "$out_empty"

(cd "$REPO" && printf '' | bash "$HOOK" >/dev/null 2>&1); rc=$?
assert_eq "empty stdin exits 0" "0" "$rc"

(cd "$REPO" && hook_stdin "$REF" "$BASE" | OCTOPUS_SKIP_AUDIT_HOOK=1 bash "$HOOK" >/dev/null 2>&1); rc=$?
assert_eq "the opt-out env var exits 0" "0" "$rc"

opt_out="$(cd "$REPO" && hook_stdin "$REF" "$BASE" | OCTOPUS_SKIP_AUDIT_HOOK=1 bash "$HOOK" 2>&1)"
assert_eq "the opt-out env var prints nothing" "" "$opt_out"

# --- the bash-4 regression -------------------------------------------------
# `enable -n mapfile` removes the builtin from the shell that runs the hook
# body, which is what a stock macOS bash 3.2 looks like. Before the fix this
# exited 1 and git rejected the push.

mapfile_rc="$(cd "$REPO" && hook_stdin "$REF" "$BASE" \
  | bash -c 'enable -n mapfile 2>/dev/null; ( source "$1" ); echo "RC=$?"' _ "$HOOK" 2>&1 \
  | grep -o 'RC=[0-9]*' | tail -1)"
assert_eq "without mapfile the hook still exits 0" "RC=0" "${mapfile_rc:-RC=missing}"

assert_eq "the hook uses no bash-4 builtins" "" \
  "$(grep -nE '\bmapfile\b|\breadarray\b|declare -A|local -A|local -n' "$HOOK" \
     | grep -v '^[0-9]*:#' || true)"

# --- stage two actually filters --------------------------------------------
# audit-money matches billing.ts by path token, but the added line hits none of
# its line_patterns, so `audit-scope` reports skip — and the hook must agree.

assert_contains "a real security change is suggested" "audit-security" "$out"
assert_not_contains "an audit with no candidate files is not suggested" "audit-money" "$out"
assert_contains "the suggestion names how many files it would look at" "file" "$out"

# The suppression must agree with the resolver that actually decides.
scope_money="$(cd "$REPO" && bash "$OCTOPUS_DIR/cli/octopus.sh" audit-scope audit-money \
  --base "$BASE" --ref "$REF" 2>&1 | head -1)"
assert_contains "the hook's suppression matches what audit-scope decides" \
  "OCTOPUS_AUDIT_SCOPE=skip" "$scope_money"

# And the suggestion must agree with it too, in the other direction.
scope_sec="$(cd "$REPO" && bash "$OCTOPUS_DIR/cli/octopus.sh" audit-scope audit-security \
  --base "$BASE" --ref "$REF" 2>&1 | head -1)"
assert_not_contains "the hook's suggestion matches what audit-scope decides" \
  "OCTOPUS_AUDIT_SCOPE=skip" "$scope_sec"

# --- graceful degradation --------------------------------------------------
# An install missing the stage-two library must fall back to stage one, not die.

FAKE="$WORK/fake-octopus"
mkdir -p "$FAKE/cli/lib" "$FAKE/hooks/git" "$FAKE/skills"
cp -r "$OCTOPUS_DIR/skills/audit-security" "$OCTOPUS_DIR/skills/audit-money" "$FAKE/skills/"
cp "$OCTOPUS_DIR/cli/lib/audit-map.sh" "$FAKE/cli/lib/"
cp "$HOOK" "$FAKE/hooks/git/"
# audit-prepass.sh deliberately absent.

degraded="$(cd "$REPO" && hook_stdin "$REF" "$BASE" | bash "$FAKE/hooks/git/$(basename "$HOOK")" 2>&1)"; rc=$?
assert_eq "a missing stage-two library still exits 0" "0" "$rc"
assert_contains "a missing stage-two library falls back to stage one" "audit-security" "$degraded"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
