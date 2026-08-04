#!/usr/bin/env bash
# tests/test_audit_scope.sh — the three-path contract of cli/lib/audit-scope.sh (RM-172).
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="$OCTOPUS_DIR/cli/lib/audit-scope.sh"
PASS=0; FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; [[ -n "${2:-}" ]] && echo "      $2"; FAIL=$((FAIL + 1)); }

assert_contains() {
  local desc="$1" needle="$2" hay="$3"
  [[ "$hay" == *"$needle"* ]] && pass "$desc" || fail "$desc" "missing [$needle] in: ${hay:0:200}"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FIXTURE="$WORK/fixture-octopus"
mkdir -p "$FIXTURE/skills/audit-fake"
cat > "$FIXTURE/skills/audit-fake/SKILL.md" <<'EOF'
---
name: audit-fake
pre_pass:
  file_patterns: "billing|payment"
  line_patterns: "\\bdecimal\\b"
---

# Fake Audit
EOF

run_scope() {
  env AUDIT_PREPASS_OCTOPUS_DIR="$FIXTURE" \
      AUDIT_CACHE_OCTOPUS_DIR="$FIXTURE" \
      bash "$SCOPE" "$@"
}

REPO="$WORK/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t
git -C "$REPO" config user.name t
echo base > "$REPO/README.md"
git -C "$REPO" add -A && git -C "$REPO" commit -qm base

pushd "$REPO" >/dev/null

# --- path 1: skip ----------------------------------------------------------

echo "irrelevant" > notes.md
git add -A && git commit -qm unrelated

out="$(run_scope audit-fake --base HEAD~1 --ref HEAD)"
rc=$?
assert_contains "skip path emits the marker" "OCTOPUS_AUDIT_SCOPE=skip" "$out"
[[ $rc -eq 0 ]] && pass "skip path exits 0" || fail "skip path exits 0" "got $rc"

# --- path 2: scoped --------------------------------------------------------

mkdir -p src
echo "decimal total = 1;" > src/billing.cs
echo "int n = 1;" > src/payment.cs
git add -A && git commit -qm change

out="$(run_scope audit-fake --base HEAD~1 --ref HEAD)"
assert_contains "scoped path emits the marker" "OCTOPUS_AUDIT_SCOPE=scoped" "$out"
assert_contains "scoped path emits a cache key" "OCTOPUS_AUDIT_CACHE_KEY=" "$out"
assert_contains "scoped path carries the scoped diff" "src/billing.cs" "$out"
if [[ "$out" != *"src/payment.cs"* ]]; then
  pass "scoped path excludes files the line filter dropped"
else
  fail "scoped path excludes files the line filter dropped"
fi

KEY="$(printf '%s\n' "$out" | awk -F= '/^OCTOPUS_AUDIT_CACHE_KEY=/{print $2}')"

# --- path 3: cached --------------------------------------------------------

printf 'HIGH (1)\n  fake: something at src/billing.cs:1\n' > "$WORK/report.md"
out="$(run_scope audit-fake --write "$KEY" --from "$WORK/report.md" --base HEAD~1 --ref HEAD)"
assert_contains "write path confirms" "OCTOPUS_AUDIT_SCOPE=written" "$out"

out="$(run_scope audit-fake --base HEAD~1 --ref HEAD)"
assert_contains "second run hits the cache" "OCTOPUS_AUDIT_SCOPE=cached" "$out"
assert_contains "cached path returns the stored report" "fake: something at src/billing.cs:1" "$out"

# A new commit changes the diff, so the cache must not answer.
echo "decimal extra = 2;" >> src/billing.cs
git add -A && git commit -qm more
out="$(run_scope audit-fake --base HEAD~2 --ref HEAD)"
assert_contains "a changed diff misses the cache" "OCTOPUS_AUDIT_SCOPE=scoped" "$out"

# --- errors ----------------------------------------------------------------

run_scope audit-does-not-exist --base HEAD~1 --ref HEAD >/dev/null 2>&1
[[ $? -eq 2 ]] && pass "unknown skill exits 2" || fail "unknown skill exits 2"

popd >/dev/null

out="$(cd "$WORK" && run_scope audit-fake 2>&1)"
assert_contains "outside a git repo it refuses" "not a git repository" "$out"

# --- registry --------------------------------------------------------------

if grep -q "^audit-scope|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  pass "audit-scope is registered as a workflow command"
else
  fail "audit-scope is registered as a workflow command"
fi

for helper in audit-prepass audit-cache; do
  if grep -q "^${helper}|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
    fail "$helper stays a helper lib, not a command"
  else
    pass "$helper stays a helper lib, not a command"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
