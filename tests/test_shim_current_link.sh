#!/usr/bin/env bash
# Regression test for RM-188: every successful `install_release` branch in the
# shim must repoint <cache root>/current at the release it just installed.
#
# Only install.sh's update_symlink did this, so the shim's own branches
# (bootstrap and dev-checkout) left `current` naming an older tree. That was
# survivable while `current` only backed version resolution; once the hook
# commands written into .claude/settings.json go through the link, a stale
# `current` means every hook silently executes the wrong release's code.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="$REPO_ROOT/bin/octopus"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label"
    echo "      expected: $expected"
    echo "      actual:   $actual"
    fail=$((fail + 1))
  fi
}

# A minimal tree that passes _release_matches_version: cli/octopus.sh, a git
# repo, and HEAD on an exact tag.
make_release_tree() {
  local dir="$1" version="$2"
  mkdir -p "$dir/cli" "$dir/bin"
  echo '#!/usr/bin/env bash' > "$dir/cli/octopus.sh"
  cp "$SHIM" "$dir/bin/octopus"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.t
  git -C "$dir" config user.name t
  git -C "$dir" add -A
  git -C "$dir" commit -qm init
  git -C "$dir" tag "$version"
}

echo "Test: dev-checkout install repoints 'current'"
checkout="$tmp/checkout"
cache_a="$tmp/cache-a"
make_release_tree "$checkout" "v9.9.9"
# Seed a stale link so the assertion proves a move, not a first write.
mkdir -p "$cache_a/cache/v0.0.1"
ln -s "$cache_a/cache/v0.0.1" "$cache_a/current"

OCTOPUS_CLI_CACHE_ROOT="$cache_a" bash "$checkout/bin/octopus" install --version v9.9.9 >/dev/null
check "current follows the dev checkout" \
  "$(cd "$checkout" && pwd -P)" "$(cd "$cache_a/current" && pwd -P)"

echo ""
echo "Test: bootstrap install (shim running from inside the cache) repoints 'current'"
cache_b="$tmp/cache-b"
target="$cache_b/cache/v8.8.8"
mkdir -p "$target/cli" "$target/bin"
echo '#!/usr/bin/env bash' > "$target/cli/octopus.sh"
cp "$SHIM" "$target/bin/octopus"
mkdir -p "$cache_b/cache/v0.0.1"
ln -s "$cache_b/cache/v0.0.1" "$cache_b/current"

OCTOPUS_CLI_CACHE_ROOT="$cache_b" bash "$target/bin/octopus" install --version v8.8.8 >/dev/null
check "current follows the bootstrapped release" \
  "$(cd "$target" && pwd -P)" "$(cd "$cache_b/current" && pwd -P)"

echo ""
echo "Test: 'current' is created when the cache has no link yet"
cache_c="$tmp/cache-c"
OCTOPUS_CLI_CACHE_ROOT="$cache_c" bash "$checkout/bin/octopus" install --version v9.9.9 >/dev/null
check "current created on a fresh cache" \
  "$(cd "$checkout" && pwd -P)" "$(cd "$cache_c/current" && pwd -P)"

echo ""
if [[ "$fail" -gt 0 ]]; then
  echo "FAILED: $fail test(s), $pass passed"
  exit 1
fi
echo "All shim current-link tests passed! ($pass)"
