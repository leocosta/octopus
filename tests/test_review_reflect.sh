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
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/verdicts.tsv" "$WORK/filtered.tsv" 2>"$WORK/summary.txt")"

assert_contains "a rejected blocker survives, demoted" "was BLOCKING; reflection: the index exists at line 12" "$out"
assert_not_contains "the summary line is not mixed into stdout" "OCTOPUS_REFLECT_SUMMARY" "$out"
assert_contains "the demoted finding keeps its origin" "[origin: dba]" "$out"
assert_contains "the demoted finding keeps its text" "Missing index at src/app.ts:20" "$out"
assert_eq "the demoted finding no longer sits under BLOCKING" "" \
  "$(printf '%s\n' "$out" | awk '/^BLOCKING/{f=1;next} /^[A-Z]+ \(/{f=0} f && /Missing index/{print "still blocking"}')"
assert_not_contains "a rejected non-blocker leaves the report" "Rounding at src/app.ts:5" "$out"
assert_contains "the dropped finding is recorded with its reason" "rounding happens in the caller" "$(cat "$WORK/filtered.tsv")"
assert_contains "the dropped row carries its original severity" "ADVISORY" "$(cat "$WORK/filtered.tsv")"
assert_contains "ineligible findings are untouched" "TODO introduced" "$out"
assert_contains "summary counts the outcome, on stderr" "OCTOPUS_REFLECT_SUMMARY kept=0 demoted=1 filtered=1" "$(cat "$WORK/summary.txt")"

# Header counts are recomputed, not left stale.
assert_contains "the emptied section's count is corrected" "BLOCKING (1)" "$out"

# Fail-open, three ways.
# The grep -v '^OCTOPUS_REFLECT_SUMMARY' strip these two used to need is gone:
# with the summary line off stdout entirely (fix round 2), a plain byte-for-byte
# compare is strictly stronger — it would now fail loudly if the summary ever
# leaked back onto stdout, instead of silently stripping it away first.
: > "$WORK/empty.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/empty.tsv")"
assert_eq "an empty verdicts file changes nothing" \
  "$(cat "$WORK/report.txt")" "$out"

out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/does-not-exist.tsv")"
assert_eq "a missing verdicts file changes nothing" \
  "$(cat "$WORK/report.txt")" "$out"

printf '1\treject\tgone\n99\treject\tno such finding\n' > "$WORK/partial.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/partial.tsv" 2>"$WORK/summary-partial.txt")"
assert_contains "an unmentioned finding is kept" "Rounding at src/app.ts:5" "$out"
assert_contains "an unknown id is ignored, per the stderr summary" "OCTOPUS_REFLECT_SUMMARY kept=1 demoted=1 filtered=0" "$(cat "$WORK/summary-partial.txt")"

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
reflect_apply main HEAD "$WORK/report.txt" "$WORK/drop-verdict.tsv" "$WORK/stale-filtered.tsv" >/dev/null 2>&1
reflect_apply main HEAD "$WORK/report.txt" "$WORK/drop-verdict.tsv" "$WORK/stale-filtered.tsv" >/dev/null 2>&1
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

# --- fix round 1 (Task 5 review) regressions --------------------------------
# Critical: apply used to report success unconditionally. It must fail closed
# when it cannot honor --filtered, and when the report rewrite itself fails —
# a caller doing `apply ... > new && mv new report` must never be told a
# truncated report was a success.

out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/verdicts.tsv" "/no/such/dir/filtered.tsv" 2>"$WORK/apply-lib-stderr.txt")"
rc=$?
assert_eq "reflect_apply fails when --filtered cannot be written" "2" "$rc"
assert_eq "reflect_apply emits no report when --filtered cannot be written" "" "$out"
assert_eq "reflect_apply leaks no raw bash redirection error" "" "$(cat "$WORK/apply-lib-stderr.txt")"

out="$(reflect_apply main HEAD "$WORK/no-such-report-for-apply.txt" "$WORK/verdicts.tsv" 2>/dev/null)"
rc=$?
assert_eq "reflect_apply fails when the rewrite pipeline itself fails" "2" "$rc"

# --- fix round 1 (Task 6 review) regressions --------------------------------
# Important: a parenthetical aside in the reason must not survive into the
# note. review-record.sh's reflection reader stops at the first ")" it sees,
# so a "(" or ")" left in the reason would either truncate it mid-sentence or
# leave the note's own wrapper unbalanced. reflect_apply strips both — and
# collapses tabs, so a literal tab in a reason cannot shift filtered_out's
# TSV columns either — so the note's own "(was <SEV>; reflection: ...)"
# parens are the only ones present.
printf '1\treject\tthe guard exists at :31 (see helper) and he said "no" \\ ok\n' > "$WORK/paren.tsv"
out="$(reflect_apply main HEAD "$WORK/report.txt" "$WORK/paren.tsv")"
assert_contains "a parenthetical aside in the reason does not truncate the note" \
  'reflection: the guard exists at :31 see helper and he said "no" \ ok)' "$out"
assert_not_contains "the reason keeps no parens of its own" \
  "(see helper)" "$out"

popd >/dev/null

# --- the command -----------------------------------------------------------

pushd "$REPO" >/dev/null

out="$(bash "$CMD" prepare --base main --ref HEAD --file "$WORK/report.txt")"
assert_contains "prepare through the CLI emits a payload" "--- FINDING 1 ---" "$out"

bash "$CMD" prepare --base main --ref HEAD --file "$WORK/nothing.txt" >/dev/null 2>&1
assert_eq "prepare exits 1 through the CLI when nothing is eligible" "1" "$?"

out="$(bash "$CMD" apply --base main --ref HEAD --file "$WORK/report.txt" \
  --verdicts "$WORK/verdicts.tsv" --filtered "$WORK/cli-filtered.tsv")"
assert_contains "apply through the CLI rewrites the report" "was BLOCKING; reflection:" "$out"

# fix round 2 regression: the documented orchestrator pipeline is
# `apply ... > <report>.new && mv <report>.new <report>`. Run it for real —
# not just reflect_apply captured into a shell variable — and prove the file
# that lands on disk never carries the stderr-only summary line, on both a
# run that demotes a finding and a fail-open run that rejects nothing.
cp "$WORK/report.txt" "$WORK/pipeline-demote.txt"
bash "$CMD" apply --base main --ref HEAD --file "$WORK/pipeline-demote.txt" \
  --verdicts "$WORK/verdicts.tsv" --filtered "$WORK/pipeline-demote-filtered.tsv" \
  > "$WORK/pipeline-demote.txt.new" && mv "$WORK/pipeline-demote.txt.new" "$WORK/pipeline-demote.txt"
assert_not_contains "the documented pipeline persists no summary line (demote case)" \
  "OCTOPUS_REFLECT_SUMMARY" "$(cat "$WORK/pipeline-demote.txt")"
assert_contains "the documented pipeline still persists the rewritten report (demote case)" \
  "was BLOCKING; reflection:" "$(cat "$WORK/pipeline-demote.txt")"

cp "$WORK/report.txt" "$WORK/pipeline-noop.txt"
bash "$CMD" apply --base main --ref HEAD --file "$WORK/pipeline-noop.txt" \
  --verdicts "$WORK/empty.tsv" \
  > "$WORK/pipeline-noop.txt.new" && mv "$WORK/pipeline-noop.txt.new" "$WORK/pipeline-noop.txt"
assert_not_contains "the documented pipeline persists no summary line (fail-open case)" \
  "OCTOPUS_REFLECT_SUMMARY" "$(cat "$WORK/pipeline-noop.txt")"
assert_eq "the documented pipeline's fail-open run leaves the report byte-identical" \
  "$(cat "$WORK/report.txt")" "$(cat "$WORK/pipeline-noop.txt")"

out="$(bash "$CMD" prepare --base main --ref HEAD --file "$WORK/no-such-report.txt" 2>&1)"; rc=$?
assert_eq "a missing report is a usage error" "2" "$rc"
assert_contains "the missing report is named" "no such file" "$out"

# Important: unknown/absent subcommand must be caught before --file is ever
# consulted, so the message is a usage message, never the --file guard's.
out="$(bash "$CMD" frobnicate 2>&1)"; rc=$?
assert_eq "an unknown subcommand is a usage error" "2" "$rc"
assert_contains "an unknown subcommand prints usage, not the --file guard" "Usage: octopus.sh review-reflect" "$out"
assert_not_contains "an unknown subcommand does not fall through to the --file guard" "no such file" "$out"

out="$(bash "$CMD" frobnicate --file "$WORK/report.txt" 2>&1)"; rc=$?
assert_eq "an unknown subcommand with a valid --file is still a usage error" "2" "$rc"
assert_contains "an unknown subcommand with a valid --file prints usage" "Usage: octopus.sh review-reflect" "$out"

out="$(bash "$CMD" 2>&1)"; rc=$?
assert_eq "no subcommand at all is a usage error" "2" "$rc"
assert_contains "no subcommand at all prints usage" "Usage: octopus.sh review-reflect" "$out"

# Important repro: a leading flag used to be swallowed as the subcommand,
# producing "unknown argument '<path>'" instead of a usage message.
out="$(bash "$CMD" --file "$WORK/report.txt" 2>&1)"; rc=$?
assert_eq "a leading flag alone is a usage error, not a value error" "2" "$rc"
assert_contains "a leading flag prints usage instead of misreading itself as an argument" \
  "Usage: octopus.sh review-reflect" "$out"
assert_not_contains "a leading flag is not blamed as an unknown argument" "unknown argument" "$out"

# Critical: an unwritable --filtered path is a clean usage error, not a raw
# bash error naming this library's internal file and line number.
out="$(bash "$CMD" apply --base main --ref HEAD --file "$WORK/report.txt" \
  --verdicts "$WORK/verdicts.tsv" --filtered "/no/such/dir/cli-filtered.tsv" 2>"$WORK/apply-cli-stderr.txt")"
rc=$?
assert_eq "an unwritable --filtered path is a usage error" "2" "$rc"
assert_eq "an unwritable --filtered path emits no report on stdout" "" "$out"
assert_contains "an unwritable --filtered path names the problem" \
  "cannot write" "$(cat "$WORK/apply-cli-stderr.txt")"
assert_not_contains "an unwritable --filtered path does not leak the library's internal file" \
  "reflect-payload.sh" "$(cat "$WORK/apply-cli-stderr.txt")"

popd >/dev/null

out="$(cd "$WORK" && bash "$CMD" prepare --file "$WORK/report.txt" 2>&1)"
assert_contains "outside a git repo it refuses" "not a git repository" "$out"

# --- registry --------------------------------------------------------------

if grep -q "^review-reflect|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  pass "review-reflect is a registered command"
else
  fail "review-reflect is a registered command"
fi

if grep -q "^reflect-payload|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  fail "reflect-payload stays a helper lib"
else
  pass "reflect-payload stays a helper lib"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
