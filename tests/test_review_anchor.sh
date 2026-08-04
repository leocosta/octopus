#!/usr/bin/env bash
# tests/test_review_anchor.sh — anchor verification for review findings (RM-170).
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$OCTOPUS_DIR/cli/lib/review-anchor.sh"
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

source "$OCTOPUS_DIR/cli/lib/anchor-verify.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REPO="$WORK/repo"
mkdir -p "$REPO/src"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t

# Base: a 10-line file.
seq 1 10 | sed 's/^/line /' > "$REPO/src/app.ts"
echo "untouched" > "$REPO/src/other.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm base

pushd "$REPO" >/dev/null

# Change line 3 and append two lines (11, 12).
sed -i '3s/.*/line 3 CHANGED/' src/app.ts
printf 'line 11\nline 12\n' >> src/app.ts
git add -A && git commit -qm change

# --- changed-line resolution ----------------------------------------------

changed="$(anchor_changed_lines HEAD~1 HEAD src/app.ts | tr '\n' ' ')"
assert_eq "changed lines are the post-image lines touched" "3 11 12 " "$changed"

assert_eq "an untouched file has no changed lines" \
  "" "$(anchor_changed_lines HEAD~1 HEAD src/other.ts)"

# --- verdicts --------------------------------------------------------------

assert_eq "a changed line anchors" \
  "anchored" "$(anchor_verify HEAD~1 HEAD src/app.ts 3)"

assert_eq "an existing but untouched line is not-in-diff" \
  "not-in-diff" "$(anchor_verify HEAD~1 HEAD src/app.ts 5)"

assert_eq "a line past EOF is out of range" \
  "line-out-of-range" "$(anchor_verify HEAD~1 HEAD src/app.ts 99)"

assert_eq "line 0 is out of range" \
  "line-out-of-range" "$(anchor_verify HEAD~1 HEAD src/app.ts 0)"

assert_eq "a non-numeric line is out of range" \
  "line-out-of-range" "$(anchor_verify HEAD~1 HEAD src/app.ts abc)"

assert_eq "a file that does not exist at ref is missing-file" \
  "missing-file" "$(anchor_verify HEAD~1 HEAD src/ghost.ts 1)"

assert_eq "the last appended line anchors" \
  "anchored" "$(anchor_verify HEAD~1 HEAD src/app.ts 12)"

# --- citation extraction ---------------------------------------------------

assert_eq "extracts path:line from a finding" \
  "$(printf 'src/app.ts\t3')" \
  "$(anchor_extract '  [origin: dba] N+1 query at src/app.ts:3 — fix it')"

assert_eq "prose without a citation yields nothing" \
  "" "$(anchor_extract 'BLOCKING (2)')"

assert_eq "a bare word with a colon is not an anchor" \
  "" "$(anchor_extract 'TODO: refactor this later')"

assert_eq "takes the first citation when several appear" \
  "$(printf 'src/a.ts\t1')" \
  "$(anchor_extract 'compare src/a.ts:1 with src/b.ts:2')"

# --- stream annotation -----------------------------------------------------

cat > "$WORK/findings.txt" <<'EOF'
BLOCKING (2)
  [origin: dba] missing index at src/app.ts:3
  [origin: architect] leak at src/app.ts:5

ADVISORY (1)
  [origin: fallback] TODO introduced at src/ghost.ts:7
EOF

out="$(bash "$CMD" --base HEAD~1 --ref HEAD --file "$WORK/findings.txt")"
rc=$?

assert_contains "real finding is marked anchored" "anchored"$'\t'"  [origin: dba]" "$out"
assert_contains "untouched-line finding is marked not-in-diff" "not-in-diff" "$out"
assert_contains "missing-file finding is marked" "missing-file" "$out"
assert_contains "a header line has no anchor" "no-anchor"$'\t'"BLOCKING (2)" "$out"
# not-in-diff is counted apart from failed — a finding about pre-existing code is
# legitimate, so only missing-file and line-out-of-range drive the exit status.
assert_contains "summary counts not-in-diff apart from failures" \
  "OCTOPUS_ANCHOR_SUMMARY anchored=1 not-in-diff=1 failed=1 no-anchor=2" "$out"
[[ $rc -eq 1 ]] && pass "exits 1 when a finding fails to anchor" || fail "exits 1 when a finding fails to anchor" "got $rc"

# A report whose only non-anchored finding is not-in-diff must still exit 0.
cat > "$WORK/pre-existing.txt" <<'EOF'
  [origin: architect] leak at src/app.ts:5
EOF
bash "$CMD" --base HEAD~1 --ref HEAD --file "$WORK/pre-existing.txt" >/dev/null 2>&1
assert_eq "not-in-diff alone does not fail the run" 0 "$?"

# All-clean input exits 0.
printf '  [origin: dba] index at src/app.ts:3\n' > "$WORK/clean.txt"
bash "$CMD" --base HEAD~1 --ref HEAD --file "$WORK/clean.txt" >/dev/null 2>&1
assert_eq "exits 0 when every anchor resolves" 0 "$?"

# stdin path.
out="$(printf '  finding at src/app.ts:3\n' | bash "$CMD" --base HEAD~1 --ref HEAD)"
assert_contains "reads findings from stdin" "anchored" "$out"

# Blank lines survive so report formatting is preserved.
blanks="$(printf 'a\n\nb\n' | bash "$CMD" --base HEAD~1 --ref HEAD --quiet; echo rc=$?)"
assert_contains "quiet mode suppresses output" "rc=0" "$blanks"

popd >/dev/null

# --- dispatcher path -------------------------------------------------------
# Regression: cli/octopus.sh sources the command with `set -e` active. A finding
# line with no citation makes anchor_extract's grep return 1, which used to abort
# the run instead of recording `no-anchor`.

pushd "$REPO" >/dev/null
out="$(bash "$OCTOPUS_DIR/cli/octopus.sh" review-anchor --base HEAD~1 --ref HEAD --file "$WORK/findings.txt" 2>&1)"
assert_contains "dispatcher: uncited lines do not abort the run" "no-anchor" "$out"
assert_contains "dispatcher: the summary still prints" "OCTOPUS_ANCHOR_SUMMARY" "$out"
assert_contains "dispatcher: anchored findings survive" "anchored" "$out"
popd >/dev/null

# --- errors ----------------------------------------------------------------

out="$(cd "$WORK" && printf 'x\n' | bash "$CMD" 2>&1)"
assert_contains "outside a git repo it refuses" "not a git repository" "$out"

# --- registry --------------------------------------------------------------

if grep -q "^review-anchor|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  pass "review-anchor is a registered command"
else
  fail "review-anchor is a registered command"
fi

if grep -q "^anchor-verify|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  fail "anchor-verify stays a helper lib"
else
  pass "anchor-verify stays a helper lib"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
