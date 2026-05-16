#!/usr/bin/env bash
# octopus:rules-sync — re-runs octopus setup when .octopus/rules/*.local.md changes.
# Installed by Octopus into post-merge and post-checkout hooks for concatenate-mode agents.
#
# post-merge:   called with no args after a successful merge
# post-checkout: called with <prev-head> <new-head> <is-branch-checkout>

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
setup_sh="$repo_root/octopus/setup.sh"
[[ -f "$setup_sh" ]] || exit 0

# Determine which commit range to diff based on how we were invoked.
is_branch_checkout="${3:-}"
if [[ -n "$is_branch_checkout" ]]; then
  # post-checkout: only react to branch switches, not file checkouts
  [[ "$is_branch_checkout" == "1" ]] || exit 0
  prev="$1"
  new="$2"
  changed=$(git diff-tree -r --name-only --no-commit-id "$prev" "$new" 2>/dev/null || true)
else
  # post-merge
  changed=$(git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD 2>/dev/null || true)
fi

echo "$changed" | grep -qE "^\.octopus/rules/.+\.local\.md$" || exit 0

echo "[octopus] .local.md rules changed — re-running setup to sync concatenated agent configs..."
cd "$repo_root" && bash "$setup_sh" --quiet 2>/dev/null \
  || echo "[octopus] WARNING: setup failed — run 'octopus setup' manually" >&2
