#!/usr/bin/env bash
# tests/test_review_reflect.sh — adversarial reflection pass over review findings (RM-171).
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$OCTOPUS_DIR/cli/lib/review-reflect.sh"
PASS=0; FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; [[ -n "${2:-}" ]] && echo "      $2"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  [[ "$expected" == "$actual" ]] && pass "$desc" || fail "$desc" "expected [$expected] got [$actual]"
}

assert_contains() {
  local desc="$1" needle="$2" hay="$3"
  [[ "$hay" == *"$needle"* ]] && pass "$desc" || fail "$desc" "missing [$needle] in: ${hay:0:200}"
}

assert_not_contains() {
  local desc="$1" needle="$2" hay="$3"
  [[ "$hay" != *"$needle"* ]] && pass "$desc" || fail "$desc" "unexpected [$needle]"
}

source "$OCTOPUS_DIR/cli/lib/reflect-payload.sh"

# --- origin eligibility ----------------------------------------------------
# Model-authored findings are adjudicable; deterministic ones are true by
# construction and must never cost a model call.

for o in architect dba security audit-money audit-tenant audit-contracts; do
  reflect_origin_eligible "$o" && pass "origin $o is eligible" || fail "origin $o is eligible"
done

for o in fallback definition-of-done unknown ""; do
  reflect_origin_eligible "$o" && fail "origin '$o' is excluded" || pass "origin '$o' is excluded"
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REPO="$WORK/repo"
mkdir -p "$REPO/src"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t

seq 1 40 | sed 's/^/line /' > "$REPO/src/app.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm base

pushd "$REPO" >/dev/null

# --- code windows ----------------------------------------------------------

win="$(reflect_code_window HEAD src/app.ts 20 3)"
assert_eq "window has 2*radius+1 lines" "7" "$(printf '%s\n' "$win" | wc -l | tr -d ' ')"
assert_contains "window marks the cited line" ">    20 | line 20" "$win"
assert_contains "window includes the lower bound" "    17 | line 17" "$win"
assert_contains "window includes the upper bound" "    23 | line 23" "$win"
assert_not_contains "window excludes beyond the upper bound" "line 24" "$win"

win="$(reflect_code_window HEAD src/app.ts 2 5)"
assert_contains "window truncates at the start of file" "     1 | line 1" "$win"
assert_eq "start-truncated window stops at line+radius" "7" "$(printf '%s\n' "$win" | wc -l | tr -d ' ')"

win="$(reflect_code_window HEAD src/app.ts 39 5)"
assert_contains "window truncates at the end of file" "    40 | line 40" "$win"
assert_eq "end-truncated window has only real lines" "7" "$(printf '%s\n' "$win" | wc -l | tr -d ' ')"

popd >/dev/null

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
