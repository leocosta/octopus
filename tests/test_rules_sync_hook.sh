#!/usr/bin/env bash
# tests/test_rules_sync_hook.sh — tests for RM-070 rules-sync git hooks.
set -euo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

check_not() {
  local desc="$1"; shift
  if ! "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

HOOK_SRC="$OCTOPUS_DIR/hooks/git/rules-sync.sh"

# T1-T3: source file checks
check "rules-sync.sh exists"        test -f "$HOOK_SRC"
check "rules-sync.sh is executable" test -x "$HOOK_SRC"
check "rules-sync.sh references .octopus/rules" grep -q "\.octopus/rules" "$HOOK_SRC"

# T4: setup.sh installs post-merge and post-checkout hooks
check "setup.sh installs post-merge rules-sync"    grep -q "post-merge"    "$OCTOPUS_DIR/setup.sh"
check "setup.sh installs post-checkout rules-sync" grep -q "post-checkout" "$OCTOPUS_DIR/setup.sh"
check "setup.sh references rules-sync hook id"     grep -q "octopus:rules-sync" "$OCTOPUS_DIR/setup.sh"

# T5: deliver_git_hooks installs post-merge and post-checkout into a temp git repo
TMPDIR=$(mktemp -d)
git -C "$TMPDIR" init -q
mkdir -p "$TMPDIR/.claude"
echo '{"permissions":{}, "hooks":{}, "mcpServers":{}}' > "$TMPDIR/.claude/settings.json"

source "$OCTOPUS_DIR/setup.sh" --source-only

export PROJECT_ROOT="$TMPDIR"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
OCTOPUS_WORKFLOW="true"
OCTOPUS_POST_MERGE_AUDIT_HOOK="false"  # disable audit hook to isolate rules-sync
OCTOPUS_SKILLS=()

deliver_git_hooks >/dev/null 2>&1

HOOKS_DIR="$TMPDIR/.git/hooks"
check "post-merge hook installed"    test -f "$HOOKS_DIR/post-merge"
check "post-checkout hook installed" test -f "$HOOKS_DIR/post-checkout"
check "post-merge references rules-sync"    grep -q "octopus:rules-sync" "$HOOKS_DIR/post-merge"
check "post-checkout references rules-sync" grep -q "octopus:rules-sync" "$HOOKS_DIR/post-checkout"
check "post-merge is executable"    test -x "$HOOKS_DIR/post-merge"
check "post-checkout is executable" test -x "$HOOKS_DIR/post-checkout"

# T6: idempotent — second deliver_git_hooks does not duplicate the hook lines
deliver_git_hooks >/dev/null 2>&1
merge_count=$(grep -c "octopus:rules-sync" "$HOOKS_DIR/post-merge" || true)
checkout_count=$(grep -c "octopus:rules-sync" "$HOOKS_DIR/post-checkout" || true)
[[ "$merge_count" -eq 1 ]]    && echo "PASS: post-merge hook is idempotent"    && PASS=$((PASS+1)) \
  || { echo "FAIL: post-merge duplicated ($merge_count occurrences)"; FAIL=$((FAIL+1)); }
[[ "$checkout_count" -eq 1 ]] && echo "PASS: post-checkout hook is idempotent" && PASS=$((PASS+1)) \
  || { echo "FAIL: post-checkout duplicated ($checkout_count occurrences)"; FAIL=$((FAIL+1)); }

rm -rf "$TMPDIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
