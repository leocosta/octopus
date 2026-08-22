#!/usr/bin/env bash
# tests/test_hooks_install.sh — `octopus hooks` install/status/uninstall.
#
# Octopus shipped three git hooks with no way to install or refresh them. Two
# were wired as wrappers delegating to an absolute path, so they self-updated;
# `pre-push` had been copied inline and froze at the version that copied it —
# on this very repo it was still a v1.80.1 snapshot, carrying two defects fixed
# in v1.98.1. These assertions are that the wrapper is what gets written, that
# the path it names is the one `octopus update` moves, and that a hook we did
# not write is never clobbered.
set -uo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$OCTOPUS_DIR/cli/lib/hooks.sh"
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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A fake release tree plus a fake cache, so nothing here touches the real
# ~/.octopus-cli. `current` is a symlink to a versioned directory — exactly the
# layout `octopus update` maintains.
RELEASE="$WORK/release"
mkdir -p "$RELEASE/cli" "$RELEASE/hooks/git"
touch "$RELEASE/cli/octopus.sh"
for s in rules-sync pre-push-audit-suggest; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$RELEASE/hooks/git/$s.sh"
done

CACHE="$WORK/cache-root"
mkdir -p "$CACHE/cache/v9.9.9/hooks/git" "$CACHE/cache/v9.9.9/cli"
touch "$CACHE/cache/v9.9.9/cli/octopus.sh"
ln -s "$CACHE/cache/v9.9.9" "$CACHE/current"

REPO="$WORK/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q

run() { (cd "$REPO" && HOOKS_RELEASE_ROOT="$RELEASE" OCTOPUS_CACHE_ROOT="$CACHE" bash "$CMD" "$@" 2>&1); }

# --- status on a bare repo -------------------------------------------------

out="$(run status)"; rc=$?
assert_eq "status exits 1 when hooks are missing" "1" "$rc"
assert_contains "status reports post-checkout missing" "post-checkout missing" "$(echo "$out" | tr -s ' ')"
assert_contains "status reports pre-push missing" "pre-push       missing" "$out"

# --- install ---------------------------------------------------------------

out="$(run install)"; rc=$?
assert_eq "install exits 0" "0" "$rc"
assert_contains "install reports what it wrote" "installed" "$out"

for h in post-checkout post-merge pre-push; do
  [[ -x "$REPO/.git/hooks/$h" ]] && pass "$h is installed and executable" || fail "$h is installed and executable"
done

body="$(cat "$REPO/.git/hooks/pre-push")"
assert_eq "the hook is a 3-line wrapper, not an inline copy" "3" "$(printf '%s\n' "$body" | wc -l | tr -d ' ')"
assert_contains "the wrapper carries the ownership marker" "# octopus:pre-push-audit-suggest" "$body"
assert_contains "the wrapper forwards its arguments" '"$@"' "$body"

# rules-sync is wired to both events git delivers it on.
assert_contains "post-checkout delegates to rules-sync" "hooks/git/rules-sync.sh" "$(cat "$REPO/.git/hooks/post-checkout")"
assert_contains "post-merge delegates to rules-sync" "hooks/git/rules-sync.sh" "$(cat "$REPO/.git/hooks/post-merge")"

out="$(run status)"; rc=$?
assert_eq "status exits 0 once installed" "0" "$rc"

out="$(run install)"
assert_contains "install is idempotent" "unchanged" "$out"
assert_not_contains "a second install rewrites nothing" "updated" "$out"

# --- the staleness this command exists to fix ------------------------------

printf '#!/usr/bin/env bash\n# octopus:pre-push-audit-suggest\n# ... 70 more lines of inlined script ...\nexit 0\n' \
  > "$REPO/.git/hooks/pre-push"
out="$(run status)"; rc=$?
assert_eq "an inlined copy reads as stale" "1" "$rc"
assert_contains "status names the stale hook" "pre-push       stale" "$out"

out="$(run install)"
assert_contains "install replaces a stale copy" "pre-push       updated" "$out"
assert_eq "the replacement is the wrapper" "3" "$(wc -l < "$REPO/.git/hooks/pre-push" | tr -d ' ')"

# --- never clobber a hook we did not write ---------------------------------

printf '#!/bin/sh\necho "someone else owns this"\n' > "$REPO/.git/hooks/pre-push"
chmod +x "$REPO/.git/hooks/pre-push"

out="$(run status)"
assert_contains "a third-party hook reads as foreign" "pre-push       foreign" "$out"

out="$(run install)"
assert_contains "install refuses to clobber it" "SKIPPED" "$out"
assert_contains "install prints the line to delegate manually" "hooks/git/pre-push-audit-suggest.sh" "$out"
assert_contains "the third-party hook survives" "someone else owns this" "$(cat "$REPO/.git/hooks/pre-push")"

out="$(run install --force)"
assert_contains "--force takes it over, saying so" "replaced" "$out"
assert_not_contains "the third-party body is gone after --force" "someone else owns this" \
  "$(cat "$REPO/.git/hooks/pre-push")"

# --- uninstall removes ours and only ours ----------------------------------

printf '#!/bin/sh\necho "not ours either"\n' > "$REPO/.git/hooks/post-merge"
out="$(run uninstall)"
assert_contains "uninstall removes our hook" "pre-push       removed" "$out"
assert_contains "uninstall leaves a foreign hook alone" "post-merge     left alone" "$out"
[[ -f "$REPO/.git/hooks/post-merge" ]] && pass "the foreign hook is still on disk" || fail "the foreign hook is still on disk"
[[ -e "$REPO/.git/hooks/pre-push" ]] && fail "our hook is gone after uninstall" || pass "our hook is gone after uninstall"

# --- the point of the whole command: a path that survives an update --------
# With no local release tree, the wrapper must name the `current` symlink and
# never the versioned directory behind it. Naming the version is the bug.

REPO2="$WORK/repo2"
mkdir -p "$REPO2"
git -C "$REPO2" init -q
(cd "$REPO2" && HOOKS_RELEASE_ROOT="$CACHE/cache/v9.9.9" OCTOPUS_CACHE_ROOT="$CACHE" bash "$CMD" install >/dev/null 2>&1)
body2="$(cat "$REPO2/.git/hooks/pre-push")"
assert_contains "without a local tree the wrapper names 'current'" "$CACHE/current/hooks/git" "$body2"
assert_not_contains "the wrapper never names a version directory" "v9.9.9" "$body2"

# --- the source is a property of the repo, not of the caller ---------------
# The first version of _hooks_source_root asked whether the RUNNING code was an
# Octopus tree, so the same repo got different hooks depending on which entry
# point touched it last: `octopus hooks install` from a working tree pointed at
# the tree, while `octopus update` — which re-runs setup from the cache —
# pointed at the release. This repo ended up with two hooks on the release and
# one on the working tree.

REPO3="$WORK/repo3"
mkdir -p "$REPO3/cli" "$REPO3/hooks/git"
git -C "$REPO3" init -q
touch "$REPO3/cli/octopus.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$REPO3/hooks/git/rules-sync.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$REPO3/hooks/git/pre-push-audit-suggest.sh"

from_tree="$( (cd "$REPO3" && HOOKS_RELEASE_ROOT="$REPO3" OCTOPUS_CACHE_ROOT="$CACHE" \
  bash "$CMD" status) | awk '/^source:/ { print $2 }')"
from_cache="$( (cd "$REPO3" && HOOKS_RELEASE_ROOT="$CACHE/cache/v9.9.9" OCTOPUS_CACHE_ROOT="$CACHE" \
  bash "$CMD" status) | awk '/^source:/ { print $2 }')"

assert_eq "the source is the same whichever entry point runs" "$from_tree" "$from_cache"
assert_eq "a repo carrying Octopus runs its own tree, not a release" "$REPO3" "$from_cache"

# Octopus vendored at <toplevel>/octopus — the layout hooks/git/rules-sync.sh
# assumes when it looks for "$repo_root/octopus/setup.sh".
REPO4="$WORK/repo4"
mkdir -p "$REPO4/octopus/cli" "$REPO4/octopus/hooks/git"
git -C "$REPO4" init -q
touch "$REPO4/octopus/cli/octopus.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$REPO4/octopus/hooks/git/rules-sync.sh"

vendored="$( (cd "$REPO4" && HOOKS_RELEASE_ROOT="$CACHE/cache/v9.9.9" OCTOPUS_CACHE_ROOT="$CACHE" \
  bash "$CMD" status) | awk '/^source:/ { print $2 }')"
assert_eq "a vendored octopus/ checkout is found too" "$REPO4/octopus" "$vendored"

# --- host-environment drift (RM-183): shared with deliver_hooks() in setup.sh
# The wrapper's source-root is an absolute POSIX path tied to whichever shell
# ran install (WSL, Git Bash, ...). A different shell reading the same
# .git/hooks/* later can't resolve it, and git's own hook invocation fails
# before this script ever runs — so install-time is the only place to catch it.

REPO5="$WORK/repo5"
mkdir -p "$REPO5"
git -C "$REPO5" init -q

out="$(cd "$REPO5" && HOOKS_RELEASE_ROOT="$RELEASE" OCTOPUS_CACHE_ROOT="$CACHE" \
  WSL_DISTRO_NAME="Ubuntu" bash "$CMD" install 2>&1)"
assert_not_contains "first-ever install (wsl) does not warn" "WARNING:" "$out"
assert_eq "marker records 'wsl'" "wsl" "$(cat "$REPO5/.octopus/setup-env")"

out="$(cd "$REPO5" && HOOKS_RELEASE_ROOT="$RELEASE" OCTOPUS_CACHE_ROOT="$CACHE" \
  MSYSTEM="MINGW64" bash "$CMD" install 2>&1)"
assert_contains "install under a drifted environment (msys) warns" "WARNING:" "$out"
assert_contains "the warning names both environments" "'wsl'" "$out"
assert_contains "the warning names both environments (2)" "'msys'" "$out"
assert_eq "marker updates to 'msys'" "msys" "$(cat "$REPO5/.octopus/setup-env")"

out="$(cd "$REPO5" && HOOKS_RELEASE_ROOT="$RELEASE" OCTOPUS_CACHE_ROOT="$CACHE" \
  MSYSTEM="MINGW64" bash "$CMD" install 2>&1)"
assert_not_contains "repeated install under the same environment stays quiet" "WARNING:" "$out"

# --- errors ----------------------------------------------------------------

out="$(cd "$WORK" && bash "$CMD" status 2>&1)"; rc=$?
assert_eq "outside a git repo it exits 2" "2" "$rc"
assert_contains "outside a git repo it says so" "not a git repository" "$out"

out="$(run frobnicate)"; rc=$?
assert_eq "an unknown subcommand exits 2" "2" "$rc"

out="$(run)"; rc=$?
assert_eq "no subcommand exits 2" "2" "$rc"

# --- registry --------------------------------------------------------------

if grep -q "^hooks|" "$OCTOPUS_DIR/cli/lib/commands.default"; then
  pass "hooks is a registered command"
else
  fail "hooks is a registered command"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
