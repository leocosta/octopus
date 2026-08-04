#!/usr/bin/env bash
# tests/test_audit_cache.sh — executable tests for cli/lib/audit-cache.sh (RM-172).
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; [[ -n "${2:-}" ]] && echo "      $2"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  [[ "$expected" == "$actual" ]] && pass "$desc" || fail "$desc" "expected [$expected] got [$actual]"
}

assert_ne() {
  local desc="$1" a="$2" b="$3"
  [[ "$a" != "$b" ]] && pass "$desc" || fail "$desc" "both were [$a]"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FIXTURE="$WORK/fixture-octopus"
mkdir -p "$FIXTURE/skills/fake-audit"
cat > "$FIXTURE/skills/fake-audit/SKILL.md" <<'EOF'
---
name: fake-audit
pre_pass:
  file_patterns: "billing"
---

# Fake Audit
EOF

source "$OCTOPUS_DIR/cli/lib/audit-cache.sh"
AUDIT_CACHE_OCTOPUS_DIR="$FIXTURE"

SANDBOX="$WORK/sandbox"
mkdir -p "$SANDBOX"
pushd "$SANDBOX" >/dev/null

printf 'diff --git a/b b/b\n+decimal x;\n' > scoped.diff
printf 'CRITICAL (1)\n  money: rounding drift at src/b.cs:12\n' > body.md

# --- T1: key derivation ----------------------------------------------------

key1="$(audit_cache_key fake-audit scoped.diff)"
if [[ ${#key1} -eq 64 ]]; then pass "key is 64 hex chars"; else fail "key is 64 hex chars" "got ${#key1}"; fi

key1b="$(audit_cache_key fake-audit scoped.diff)"
assert_eq "key is stable across runs" "$key1" "$key1b"

audit_cache_key does-not-exist scoped.diff >/dev/null 2>&1
assert_eq "unknown skill exits 2" 2 "$?"

# Byte-compatibility with skills/_shared/audit-cache.md, so entries written
# before RM-172 still hit. This is the literal derivation from the fragment.
legacy_skill_hash="$(sha256sum "$FIXTURE/skills/fake-audit/SKILL.md" | cut -c1-64)"
legacy_scoped_diff="$(cat scoped.diff)"
legacy_key="$(printf '%s' "${legacy_scoped_diff}${legacy_skill_hash}" | sha256sum | cut -c1-64)"
assert_eq "key matches the prose protocol derivation" "$legacy_key" "$key1"

# --- T2: miss → write → hit ------------------------------------------------

audit_cache_lookup fake-audit "$key1" >/dev/null 2>&1
assert_eq "cold lookup is a miss" 1 "$?"

audit_cache_write fake-audit "$key1" body.md main HEAD
if [[ -f ".octopus/cache/fake-audit/${key1}.md" ]]; then
  pass "write lands at .octopus/cache/<skill>/<key>.md"
else
  fail "write lands at .octopus/cache/<skill>/<key>.md"
fi

hit="$(audit_cache_lookup fake-audit "$key1")"
assert_eq "hit returns the body with frontmatter stripped" "$(cat body.md)" "$hit"

if grep -q "^created_at:" ".octopus/cache/fake-audit/${key1}.md" \
   && grep -q "^skill: fake-audit" ".octopus/cache/fake-audit/${key1}.md"; then
  pass "entry keeps the documented frontmatter"
else
  fail "entry keeps the documented frontmatter"
fi

# --- T3: invalidation ------------------------------------------------------

printf 'diff --git a/b b/b\n+decimal y;\n' > other.diff
key_other="$(audit_cache_key fake-audit other.diff)"
assert_ne "a different diff yields a different key" "$key1" "$key_other"

audit_cache_lookup fake-audit "$key_other" >/dev/null 2>&1
assert_eq "the changed diff misses" 1 "$?"

cat >> "$FIXTURE/skills/fake-audit/SKILL.md" <<'EOF'

## New check
EOF
key_after_skill_change="$(audit_cache_key fake-audit scoped.diff)"
assert_ne "editing the SKILL.md invalidates the key" "$key1" "$key_after_skill_change"

# --- T4: gitignore guard ---------------------------------------------------

assert_eq "guard added the cache dir once" "1" "$(grep -cF '.octopus/cache/' .gitignore)"

audit_cache_write fake-audit "$key_other" body.md main HEAD
assert_eq "guard is idempotent" "1" "$(grep -cF '.octopus/cache/' .gitignore)"

# --- T5: hash portability --------------------------------------------------
# A cache written on Linux (sha256sum) must be readable on macOS (shasum). That
# holds only if every supported implementation produces the same digest, so
# assert the equality directly rather than simulating a missing binary.

baseline="$(AUDIT_CACHE_HASH_TOOL=sha256sum audit_cache_key fake-audit scoped.diff)"

for tool in shasum openssl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $tool not installed"
    continue
  fi
  alt="$(AUDIT_CACHE_HASH_TOOL="$tool" audit_cache_key fake-audit scoped.diff)"
  assert_eq "$tool yields the same key as sha256sum" "$baseline" "$alt"
done

AUDIT_CACHE_HASH_TOOL=definitely-not-a-hash-tool audit_cache_key fake-audit scoped.diff >/dev/null 2>&1
assert_eq "an unavailable pinned tool fails loudly" 1 "$?"

popd >/dev/null

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
