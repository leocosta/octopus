#!/usr/bin/env bash
# tests/test_review_session.sh — structured review records (RM-176).
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$OCTOPUS_DIR/cli/lib/review-session.sh"
PASS=0; FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; [[ -n "${2:-}" ]] && echo "      $2"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  [[ "$expected" == "$actual" ]] && pass "$desc" || fail "$desc" "expected [$expected] got [$actual]"
}
assert_contains() {
  local desc="$1" needle="$2" hay="$3"
  [[ "$hay" == *"$needle"* ]] && pass "$desc" || fail "$desc" "missing [$needle] in: ${hay:0:300}"
}

source "$OCTOPUS_DIR/cli/lib/review-record.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REPO="$WORK/repo"
mkdir -p "$REPO/src"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t
seq 1 10 | sed 's/^/line /' > "$REPO/src/app.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm base

pushd "$REPO" >/dev/null
sed -i '3s/.*/line 3 CHANGED/' src/app.ts
git add -A && git commit -qm change

cat > "$WORK/report.md" <<'EOF'
Code Review Report
==================

BLOCKING (2)
  [origin: dba] missing index at src/app.ts:3
  [origin: architect] ghost reference at src/gone.ts:9

ADVISORY (1)
  [origin: audit-contracts] DTO drift at src/app.ts:7

QUESTION (1)
  [origin: dba] cannot verify table size — set MSSQL_CONNECTION_STRING
EOF

printf 'audit-money scoped\naudit-tenant skip\naudit-security cached\n' > "$WORK/audits.txt"

# --- parsing ---------------------------------------------------------------

rows="$(review_record_parse HEAD~1 HEAD "$WORK/report.md")"
assert_eq "parses one row per finding" "4" "$(printf '%s\n' "$rows" | grep -c .)"

assert_contains "severity comes from the section header" \
  "BLOCKING"$'\t'"dba"$'\t'"src/app.ts"$'\t'"3"$'\t'"anchored" "$rows"

assert_contains "a finding on an untouched line records not-in-diff" \
  "ADVISORY"$'\t'"audit-contracts"$'\t'"src/app.ts"$'\t'"7"$'\t'"not-in-diff" "$rows"

assert_contains "a finding on a missing file records missing-file" \
  "BLOCKING"$'\t'"architect"$'\t'"src/gone.ts"$'\t'"9"$'\t'"missing-file" "$rows"

assert_contains "a finding with no citation records no-anchor" \
  "QUESTION"$'\t'"dba"$'\t'$'\t'$'\t'"no-anchor" "$rows"

if printf '%s\n' "$rows" | grep -q "Code Review Report"; then
  fail "report chrome is not treated as a finding"
else
  pass "report chrome is not treated as a finding"
fi

# --- record ----------------------------------------------------------------

out="$(bash "$CMD" record --base HEAD~1 --ref HEAD --report "$WORK/report.md" --audits "$WORK/audits.txt")"
assert_contains "record emits the session id" "OCTOPUS_REVIEW_SESSION=" "$out"
assert_contains "record counts findings" "findings: 4" "$out"
assert_contains "record counts unanchored separately" "unanchored: 1" "$out"

id="$(printf '%s\n' "$out" | sed -n 's/^OCTOPUS_REVIEW_SESSION=//p')"
file=".octopus/reviews/${id}.json"
[[ -f "$file" ]] && pass "record lands in .octopus/reviews" || fail "record lands in .octopus/reviews"

if jq empty "$file" 2>/dev/null; then
  pass "record is valid JSON"
else
  fail "record is valid JSON" "$(head -20 "$file")"
fi

assert_eq "record keeps the audit resolutions" "3" "$(jq '.audits | length' "$file")"
assert_eq "record keeps the skip outcome" '"skip"' "$(jq '.audits[] | select(.name=="audit-tenant") | .outcome' "$file")"
assert_eq "record keeps every finding" "4" "$(jq '.findings | length' "$file")"
assert_eq "record keeps the anchor verdict" '"missing-file"' \
  "$(jq '.findings[] | select(.origin=="architect") | .anchor' "$file")"
assert_eq "a finding without a citation has null path" "null" \
  "$(jq '.findings[] | select(.severity=="QUESTION") | .path' "$file")"
assert_eq "record pins the reviewed sha" "$(git rev-parse HEAD)" "$(jq -r '.ref_sha' "$file")"

assert_eq "gitignore guard added the records dir once" "1" "$(grep -cF '.octopus/reviews/' .gitignore)"
bash "$CMD" record --base HEAD~1 --ref HEAD --report "$WORK/report.md" >/dev/null
assert_eq "gitignore guard is idempotent" "1" "$(grep -cF '.octopus/reviews/' .gitignore)"

# --- id collision ----------------------------------------------------------
# Re-running a review after a fix produces a second record for the same sha,
# often within the same second. It must not overwrite the first.

before=$(ls .octopus/reviews/*.json | wc -l)
bash "$CMD" record --base HEAD~1 --ref HEAD --report "$WORK/report.md" >/dev/null
bash "$CMD" record --base HEAD~1 --ref HEAD --report "$WORK/report.md" >/dev/null
after=$(ls .octopus/reviews/*.json | wc -l)
assert_eq "same-second records do not overwrite each other" "$((before + 2))" "$after"

# --- quoting -------------------------------------------------------------

cat > "$WORK/tricky.md" <<'EOF'
BLOCKING (1)
  [origin: dba] he said "quoted" and used a \backslash at src/app.ts:3
EOF
out="$(bash "$CMD" record --base HEAD~1 --ref HEAD --report "$WORK/tricky.md")"
tid="$(printf '%s\n' "$out" | sed -n 's/^OCTOPUS_REVIEW_SESSION=//p')"
if jq empty ".octopus/reviews/${tid}.json" 2>/dev/null; then
  pass "quotes and backslashes survive as valid JSON"
else
  fail "quotes and backslashes survive as valid JSON"
fi
assert_contains "the quoted text is preserved" 'he said "quoted"' \
  "$(jq -r '.findings[0].text' ".octopus/reviews/${tid}.json")"

# --- list / show -----------------------------------------------------------

assert_contains "list shows a record" "$id" "$(bash "$CMD" list)"

out="$(bash "$CMD" show "$id" --severity BLOCKING --json)"
assert_eq "severity filter selects only matching findings" "2" "$(printf '%s' "$out" | jq 'length')"

out="$(bash "$CMD" show "$id" --severity blocking,advisory --json)"
assert_eq "severity filter is case-insensitive and multi-valued" "3" "$(printf '%s' "$out" | jq 'length')"

out="$(bash "$CMD" show latest --json)"
assert_contains "show latest resolves to a record" '"findings"' "$out"

bash "$CMD" show does-not-exist >/dev/null 2>&1
assert_eq "unknown id exits 1" 1 "$?"

# --- review-log-capture consumes the record (RM-093 ← RM-176) --------------
# The hook previously grepped the transcript, which cannot supply src= or file=
# even though continuous-learning's documented format has both.

HOOK="$OCTOPUS_DIR/hooks/stop/review-log-capture.sh"
rm -rf .octopus/review-log
echo '{"transcript_path":"/nonexistent"}' | bash "$HOOK" >/dev/null 2>&1
log="$(cat .octopus/review-log/*.md 2>/dev/null || true)"

assert_contains "hook emits the origin as src=" "src=dba" "$log"
assert_contains "hook emits the anchored location as file=" "file=src/app.ts:3" "$log"
assert_contains "hook keeps the documented severity field" "sev=BLOCKING" "$log"

if printf '%s' "$log" | grep -q 'topic="\[origin'; then
  fail "hook strips the origin tag from the topic"
else
  pass "hook strips the origin tag from the topic"
fi

lines_first=$(printf '%s\n' "$log" | grep -c . || true)
echo '{"transcript_path":"/nonexistent"}' | bash "$HOOK" >/dev/null 2>&1
lines_second=$(cat .octopus/review-log/*.md | grep -c . || true)
assert_eq "already-consumed records are not re-appended" "$lines_first" "$lines_second"

[[ -f .octopus/review-log/.last-record ]] && pass "hook records a watermark" || fail "hook records a watermark"

popd >/dev/null

# --- errors ----------------------------------------------------------------

out="$(cd "$WORK" && bash "$CMD" list 2>&1)"
assert_contains "outside a git repo it refuses" "not a git repository" "$out"

out="$(cd "$REPO" && bash "$CMD" record --base HEAD~1 --ref HEAD 2>&1)"
assert_contains "record without a report is a usage error" "--report" "$out"

# --- registry --------------------------------------------------------------

if grep -q "^review-session|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  pass "review-session is a registered command"
else
  fail "review-session is a registered command"
fi
if grep -q "^review-record|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  fail "review-record stays a helper lib"
else
  pass "review-record stays a helper lib"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
