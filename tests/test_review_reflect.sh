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

# --- report scan -----------------------------------------------------------
# A report mixing eligible and ineligible findings. src/app.ts:20 is touched by
# the diff below; src/app.ts:5 is not; missing.ts does not exist at HEAD.

pushd "$REPO" >/dev/null
sed -i '20s/.*/line 20 CHANGED/' src/app.ts
git add -A && git commit -qm change

cat > "$WORK/report.txt" <<'EOF'
Code Review Report
==================
Date: 2026-08-04

BLOCKING (2)
  [origin: dba] Missing index at src/app.ts:20
  [origin: fallback] TODO introduced at src/app.ts:20

ADVISORY (3)
  [origin: audit-money] Rounding at src/app.ts:5
  [origin: architect] Layering is unclear here
  [origin: audit-tenant] No tenant filter at missing.ts:9

QUESTION (1)
  [origin: dba] Cannot verify table size
EOF

scan="$(_reflect_scan main HEAD "$WORK/report.txt")"

ids_of() { printf '%s\n' "$scan" | awk -F'\t' -v k=finding '$2 == k { print $4 ":" $5 ":" $6 }'; }

assert_eq "scan numbers eligible findings from 1, in report order" \
  "1:src/app.ts:20
2:src/app.ts:5" "$(ids_of)"

assert_contains "scan records the section header in force" $'\theader\tBLOCKING\t' "$scan"

skipped="$(printf '%s\n' "$scan" | awk -F'\t' '$2 == "skip" { c++ } END { print c+0 }')"
assert_eq "ineligible findings are scanned but never given an id" "4" "$skipped"

# The four skips, each for a different reason:
#   fallback          → origin not model-authored
#   architect (prose) → no anchor to confront
#   missing.ts        → anchor already failed in Phase 4.5
#   dba (prose)       → eligible origin but no anchor, same path as architect
assert_eq "an eligible origin with no anchor is not adjudicable" "" \
  "$(printf '%s\n' "$scan" | awk -F'\t' '$2 == "finding" && $5 == "" { print "leaked" }')"
popd >/dev/null

# --- payload ---------------------------------------------------------------

pushd "$REPO" >/dev/null
payload="$(reflect_prepare main HEAD "$WORK/report.txt")"
rc=$?

assert_eq "prepare exits 0 when something is eligible" "0" "$rc"
assert_contains "payload declares the model tier as data" "OCTOPUS_REFLECT_MODEL sonnet" "$payload"
assert_contains "payload opens each finding with its id" "--- FINDING 1 ---" "$payload"
assert_contains "payload carries the second finding too" "--- FINDING 2 ---" "$payload"
assert_eq "payload carries exactly the eligible findings" "2" \
  "$(printf '%s\n' "$payload" | grep -c '^--- FINDING ')"
assert_contains "payload states the severity" "severity: BLOCKING" "$payload"
assert_contains "payload carries the finding text" "Missing index at src/app.ts:20" "$payload"
assert_contains "payload shows the anchored code, cited line marked" ">    20 | line 20 CHANGED" "$payload"
assert_not_contains "payload never carries an ineligible finding" "TODO introduced" "$payload"
assert_not_contains "payload never carries an unanchored finding" "Layering is unclear" "$payload"

# Nothing eligible → no payload, and the caller must not spawn a sub-agent.
cat > "$WORK/nothing.txt" <<'EOF'
BLOCKING (1)
  [origin: fallback] TODO introduced at src/app.ts:20
EOF
out="$(reflect_prepare main HEAD "$WORK/nothing.txt")"; rc=$?
assert_eq "prepare exits 1 when nothing is eligible" "1" "$rc"
assert_eq "prepare emits no payload when nothing is eligible" "" "$out"
popd >/dev/null

# --- verdict application ---------------------------------------------------

pushd "$REPO" >/dev/null

# Finding 1 is the BLOCKING dba one; finding 2 the ADVISORY audit-money one.
printf '1\treject\tthe index exists at line 12\n2\treject\trounding happens in the caller\n' > "$WORK/verdicts.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/verdicts.tsv" "$WORK/filtered.tsv")"

assert_contains "a rejected blocker survives, demoted" "was BLOCKING; reflection: the index exists at line 12" "$out"
assert_contains "the demoted finding keeps its origin" "[origin: dba]" "$out"
assert_contains "the demoted finding keeps its text" "Missing index at src/app.ts:20" "$out"
assert_eq "the demoted finding no longer sits under BLOCKING" "" \
  "$(printf '%s\n' "$out" | awk '/^BLOCKING/{f=1;next} /^[A-Z]+ \(/{f=0} f && /Missing index/{print "still blocking"}')"
assert_not_contains "a rejected non-blocker leaves the report" "Rounding at src/app.ts:5" "$out"
assert_contains "the dropped finding is recorded with its reason" "rounding happens in the caller" "$(cat "$WORK/filtered.tsv")"
assert_contains "the dropped row carries its original severity" "ADVISORY" "$(cat "$WORK/filtered.tsv")"
assert_contains "ineligible findings are untouched" "TODO introduced" "$out"
assert_contains "summary counts the outcome" "OCTOPUS_REFLECT_SUMMARY kept=0 demoted=1 filtered=1" "$out"

# Header counts are recomputed, not left stale.
assert_contains "the emptied section's count is corrected" "BLOCKING (1)" "$out"

# Fail-open, three ways.
: > "$WORK/empty.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/empty.tsv")"
assert_eq "an empty verdicts file changes nothing" \
  "$(cat "$WORK/report.txt")" "$(printf '%s\n' "$out" | grep -v '^OCTOPUS_REFLECT_SUMMARY')"

out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/does-not-exist.tsv")"
assert_eq "a missing verdicts file changes nothing" \
  "$(cat "$WORK/report.txt")" "$(printf '%s\n' "$out" | grep -v '^OCTOPUS_REFLECT_SUMMARY')"

printf '1\treject\tgone\n99\treject\tno such finding\n' > "$WORK/partial.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/partial.tsv")"
assert_contains "an unmentioned finding is kept" "Rounding at src/app.ts:5" "$out"
assert_contains "an unknown id is ignored" "OCTOPUS_REFLECT_SUMMARY kept=1 demoted=1 filtered=0" "$out"

printf '1\tkeep\tthe index really is missing\n' > "$WORK/keep.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/keep.tsv")"
assert_contains "a kept blocker stays blocking" "BLOCKING (2)" "$out"
assert_not_contains "a kept finding gains no reflection note" "reflection:" "$out"

# --- fix round 1 regressions -------------------------------------------------

# Critical: "&" in a reason must not be read as sub()'s matched-text idiom.
printf '1\treject\tcost & benefit say no\n' > "$WORK/amp.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/amp.tsv")"
assert_contains "an ampersand in the reason survives literally" \
  "reflection: cost & benefit say no" "$out"
assert_not_contains "an ampersand in the reason does not inject a stray ]" \
  "cost ] benefit" "$out"

# Important: the note must land after the "]" that closes [origin: x],
# not after the first "]" on the line — probed with a markdown checkbox
# bullet, a plausible report shape that has an earlier "]".
cat > "$WORK/checkbox-report.txt" <<'EOF'
BLOCKING (1)
- [ ] [origin: dba] Missing index at src/app.ts:20
EOF
printf '1\treject\tno index needed\n' > "$WORK/checkbox-verdict.tsv"
out="$(reflect_apply main HEAD "$WORK/checkbox-report.txt" "$WORK/checkbox-verdict.tsv")"
assert_contains "the reflection note lands after the [origin: x] tag" \
  "[origin: dba] (was BLOCKING; reflection: no index needed) Missing index at src/app.ts:20" "$out"
assert_not_contains "an earlier bracket on the line is not mistaken for the tag's close" \
  "- [ ] (was BLOCKING" "$out"

# Important: filtered-out is truncated once per call, not appended to forever.
printf 'STALE-ROW-FROM-A-PREVIOUS-RUN\n' > "$WORK/stale-filtered.tsv"
printf '2\treject\trounding happens in the caller\n' > "$WORK/drop-verdict.tsv"
reflect_apply main HEAD "$WORK/report.txt" "$WORK/drop-verdict.tsv" "$WORK/stale-filtered.tsv" >/dev/null
reflect_apply main HEAD "$WORK/report.txt" "$WORK/drop-verdict.tsv" "$WORK/stale-filtered.tsv" >/dev/null
assert_not_contains "filtered-out does not retain rows from a previous run" \
  "STALE-ROW-FROM-A-PREVIOUS-RUN" "$(cat "$WORK/stale-filtered.tsv")"
assert_eq "filtered-out holds exactly one row after two identical runs" \
  "1" "$(wc -l < "$WORK/stale-filtered.tsv" | tr -d ' ')"

# Important: _reflect_recount must not clobber prose shaped like a header —
# probed on a fail-open no-op run (empty verdicts, nothing rejected).
cat > "$WORK/prose-header-report.txt" <<'EOF'
BLOCKING (1)
  [origin: dba] Missing index at src/app.ts:20

ADVISORY (0)
  MEDIUM: the caching layer should be revisited next quarter
EOF
out="$(reflect_apply main HEAD "$WORK/prose-header-report.txt" "$WORK/empty.tsv")"
assert_contains "a prose line shaped like a header survives a no-op recount" \
  "MEDIUM: the caching layer should be revisited next quarter" "$out"
assert_not_contains "the prose line is not rewritten into a bogus count" \
  "MEDIUM (0)" "$out"

# --- fix round 2 regressions -------------------------------------------------
# Round 1's escaping fixed "&" but doubled every literal "\" in the same pass
# (a replacement-string escape applied to text no longer used as one). Splicing
# with match()+substr() instead removes the need for any such escaping.

# A lone backslash, not adjacent to any "&" — exactly what round 1 missed,
# since a "\" immediately before "&" happened to round-trip by coincidence.
printf '1\treject\tpath is C:\\Users\\foo and that is wrong\n' > "$WORK/backslash.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/backslash.tsv")"
assert_contains "a lone backslash in the reason is not doubled" \
  'reflection: path is C:\Users\foo and that is wrong' "$out"
assert_not_contains "a lone backslash in the reason is not doubled (regression check)" \
  'C:\\Users\\foo' "$out"

# Backslash and ampersand together — the case that happened to survive round 1.
printf '1\treject\ta\\&b weirdness\n' > "$WORK/backslash-amp.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/backslash-amp.tsv")"
assert_contains "a backslash next to an ampersand round-trips exactly" \
  'reflection: a\&b weirdness' "$out"

popd >/dev/null

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
