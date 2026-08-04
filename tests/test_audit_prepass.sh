#!/usr/bin/env bash
# tests/test_audit_prepass.sh — executable tests for cli/lib/audit-prepass.sh (RM-172).
#
# Unlike the prose-era tests, these run the implementation against throwaway git
# repositories and assert behaviour.
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; [[ -n "${2:-}" ]] && echo "      $2"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected [$expected] got [$actual]"
  fi
}

assert_rc() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected exit $expected, got $actual"
  fi
}

# --- fixtures --------------------------------------------------------------

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FIXTURE_SKILLS="$WORK/fixture-octopus"
mkdir -p "$FIXTURE_SKILLS/skills/fake-audit" "$FIXTURE_SKILLS/skills/no-line-filter"

cat > "$FIXTURE_SKILLS/skills/fake-audit/SKILL.md" <<'EOF'
---
name: fake-audit
model: sonnet
pre_pass:
  file_patterns: "billing|payment|\\.env"
  line_patterns: "\\bdecimal\\b|SECRET"
---

# Fake Audit
EOF

cat > "$FIXTURE_SKILLS/skills/no-line-filter/SKILL.md" <<'EOF'
---
name: no-line-filter
pre_pass:
  file_patterns: "billing"
---

# No Line Filter
EOF

make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.t
  git -C "$dir" config user.name t
  echo "base" > "$dir/README.md"
  git -C "$dir" add -A
  git -C "$dir" commit -qm base
}

# --- T1: YAML escape handling ---------------------------------------------
# The frontmatter carries "\\.env"; the regex that must run is \.env.

source "$OCTOPUS_DIR/cli/lib/audit-prepass.sh"
AUDIT_PREPASS_OCTOPUS_DIR="$FIXTURE_SKILLS"

assert_eq "file_patterns unescapes \\\\. to \\." \
  'billing|payment|\.env' \
  "$(audit_prepass_file_patterns fake-audit)"

assert_eq "line_patterns unescapes \\\\b to \\b" \
  '\bdecimal\b|SECRET' \
  "$(audit_prepass_line_patterns fake-audit)"

assert_eq "missing line_patterns resolves empty" \
  '' \
  "$(audit_prepass_line_patterns no-line-filter)"

audit_prepass_file_patterns does-not-exist >/dev/null 2>&1
assert_rc "unknown skill exits 2" 2 "$?"

# --- T2: candidate selection ----------------------------------------------

REPO="$WORK/repo1"
make_repo "$REPO"
pushd "$REPO" >/dev/null

mkdir -p src
echo "decimal total = 1;" > src/billing.cs        # path match + line match
echo "int count = 1;"     > src/payment.cs        # path match, no line match
echo "decimal x = 2;"     > src/unrelated.cs      # line match, no path match
echo "KEY=1"              > .env                  # path match via \.env, no line match
git add -A && git commit -qm change

assert_eq "candidates keep only path+line matches" \
  "src/billing.cs" \
  "$(audit_prepass_candidates fake-audit HEAD~1 HEAD)"

assert_eq "without line_patterns, path match is enough" \
  "src/billing.cs" \
  "$(audit_prepass_candidates no-line-filter HEAD~1 HEAD)"

out="$(audit_prepass_diff fake-audit HEAD~1 HEAD)"
if [[ "$out" == "## Scoped files"* && "$out" == *"src/billing.cs"* && "$out" != *"unrelated"* ]]; then
  pass "diff block carries the scoped header and only scoped files"
else
  fail "diff block carries the scoped header and only scoped files"
fi

popd >/dev/null

# --- T3: early exit --------------------------------------------------------

REPO2="$WORK/repo2"
make_repo "$REPO2"
pushd "$REPO2" >/dev/null

echo "nothing relevant" > docs.md
git add -A && git commit -qm unrelated

audit_prepass_candidates fake-audit HEAD~1 HEAD >/dev/null 2>&1
assert_rc "no path match exits 1 (early exit)" 1 "$?"

audit_prepass_diff fake-audit HEAD~1 HEAD >/dev/null 2>&1
assert_rc "diff propagates the early exit" 1 "$?"

popd >/dev/null

# --- T4: line filter looks at added lines only -----------------------------

REPO3="$WORK/repo3"
make_repo "$REPO3"
pushd "$REPO3" >/dev/null

mkdir -p src
printf 'decimal gone = 1;\nint kept = 2;\n' > src/billing.cs
git add -A && git commit -qm seed

printf 'int kept = 2;\n' > src/billing.cs   # removes the only decimal line
git add -A && git commit -qm remove

audit_prepass_candidates fake-audit HEAD~1 HEAD >/dev/null 2>&1
assert_rc "a removed matching line does not qualify a file" 1 "$?"

popd >/dev/null

# --- T5: parity with the prose pipeline, against the real skills -----------
# For each shipped audit, the compiled candidate set must equal the set the
# documented shell pipeline produces.

AUDIT_PREPASS_OCTOPUS_DIR="$OCTOPUS_DIR"

REPO4="$WORK/repo4"
make_repo "$REPO4"
pushd "$REPO4" >/dev/null

mkdir -p src app
cat > src/PaymentController.cs <<'EOF'
[HttpPost]
public decimal Charge(decimal amount) { return amount; }
EOF
cat > src/tenantScope.ts <<'EOF'
const tenantId = ctx.tenantId;
EOF
cat > src/authMiddleware.ts <<'EOF'
const token = req.headers.Authorization;
EOF
echo "SECRET=1" > .env
git add -A && git commit -qm parity

for skill in audit-money audit-security audit-tenant audit-contracts; do
  fp="$(audit_prepass_file_patterns "$skill")"
  lp="$(audit_prepass_line_patterns "$skill")"

  # The literal pipeline from skills/_shared/audit-pre-pass.md.
  expected="$(git diff --name-only HEAD~1..HEAD | grep -E "$fp" || true)"
  if [[ -n "$expected" && -n "$lp" ]]; then
    kept=""
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      if git diff HEAD~1..HEAD -- "$f" | grep -E "^\+" | grep -qE "$lp"; then
        kept+="${f}"$'\n'
      fi
    done <<< "$expected"
    expected="${kept%$'\n'}"
  fi

  actual="$(audit_prepass_candidates "$skill" HEAD~1 HEAD)" || actual=""
  assert_eq "parity: $skill" "$expected" "$actual"
done

popd >/dev/null

# --- T6: the four skills still declare pre_pass ----------------------------
# Preserved from tests/test_pre_llm_audit_pass.sh — the one assertion there
# that survives the move from prose to code.

for skill in audit-money audit-security audit-tenant audit-contracts; do
  if grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/$skill/SKILL.md"; then
    pass "$skill declares pre_pass"
  else
    fail "$skill declares pre_pass"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
