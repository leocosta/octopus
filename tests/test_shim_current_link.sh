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
echo "Test: a non-symlink 'current' warns and does not abort the install"
# install.ps1 creates `current` as a Windows junction, which Git Bash/MSYS2
# reports as a plain directory. `rm -f` on it fails, and under `set -e` that
# killed install_release before metadata was ever written — with the warning
# update_current already carried left unreachable. `rm -rf` is not the fix
# either: MSYS2 recurses through a junction and would delete the release tree.
cache_d="$tmp/cache-d"
mkdir -p "$cache_d/current"
marker="$cache_d/current/do-not-delete"
touch "$marker"

out="$(OCTOPUS_CLI_CACHE_ROOT="$cache_d" bash "$checkout/bin/octopus" install --version v9.9.9 2>&1)"
rc=$?

check "install still succeeds" "0" "$rc"
check "metadata was written" "v9.9.9" \
  "$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$cache_d/metadata.json" 2>/dev/null)"
check "the non-symlink current is left in place" "yes" \
  "$([[ -d "$cache_d/current" && ! -L "$cache_d/current" ]] && echo yes || echo no)"
check "its contents are not deleted" "yes" \
  "$([[ -e "$marker" ]] && echo yes || echo no)"
check "the user is warned" "yes" \
  "$(grep -q "is not a symlink" <<<"$out" && echo yes || echo no)"

echo ""
echo "Test: a failed download leaves 'current' and its target intact"
# The shim used to rm -rf the target BEFORE invoking the installer. When the
# link already named that version this dangled `current` for the whole network
# fetch, and forever if the fetch failed — the outage RM-188 exists to prevent,
# reintroduced by the installer itself. install.sh clears the destination
# itself, after the download and right before the mv, which is the right
# moment.
cache_e="$tmp/cache-e"
old_rel="$cache_e/cache/v1.0.0"
doomed="$cache_e/cache/v2.0.0"
mkdir -p "$old_rel/cli" "$old_rel/bin" "$doomed"
echo '#!/usr/bin/env bash' > "$old_rel/cli/octopus.sh"
cp "$SHIM" "$old_rel/bin/octopus"
# No .git, so _release_matches_version fails and the flow reaches the download
# branch; no install.sh in the tree, so the installer fallback cannot succeed.
touch "$doomed/do-not-delete"
ln -s "$doomed" "$cache_e/current"

# Bogus release coordinates: the curl 404s (or fails outright offline), and
# with no $RELEASE_ROOT/install.sh to fall back to the download must fail.
# rc captured via `|| rc=$?` — this script runs under `set -e` and the command
# is expected to fail.
rc=0
OCTOPUS_CLI_CACHE_ROOT="$cache_e" OCTOPUS_RELEASE_OWNER="octopus-no-such-owner" \
  OCTOPUS_RELEASE_NAME="no-such-repo" \
  bash "$old_rel/bin/octopus" install --version v2.0.0 >/dev/null 2>&1 || rc=$?

check "the failed install reports failure" "1" "$rc"
check "the existing release tree survives" "yes" \
  "$([[ -e "$doomed/do-not-delete" ]] && echo yes || echo no)"
check "current still resolves after the failure" "yes" \
  "$([[ -e "$cache_e/current" ]] && echo yes || echo no)"

echo ""
if [[ "$fail" -gt 0 ]]; then
  echo "FAILED: $fail test(s), $pass passed"
  exit 1
fi
echo "All shim current-link tests passed! ($pass)"
