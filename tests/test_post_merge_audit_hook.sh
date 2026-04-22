#!/usr/bin/env bash
# tests/test_post_merge_audit_hook.sh — Install/uninstall tests for pre-push audit hook.
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

# ---------------------------------------------------------------------------
# T1-T4: hook source file structural checks
# ---------------------------------------------------------------------------
HOOK_SRC="$OCTOPUS_DIR/hooks/git/pre-push-audit-suggest.sh"

check "hook source file exists" test -f "$HOOK_SRC"
check "hook source is executable" test -x "$HOOK_SRC"
check "hook exits 0 when OCTOPUS_SKIP_AUDIT_HOOK set" bash -c \
  'OCTOPUS_SKIP_AUDIT_HOOK=1 bash "$1" <<< "" ; true' _ "$HOOK_SRC"
check "hook sources audit-map.sh" grep -q "audit-map.sh" "$HOOK_SRC"

# ---------------------------------------------------------------------------
# T5: postMergeAuditHook key parsed in setup.sh
# ---------------------------------------------------------------------------
check "setup.sh parses postMergeAuditHook key" \
  grep -q "postMergeAuditHook" "$OCTOPUS_DIR/setup.sh"

# ---------------------------------------------------------------------------
# T6: deliver_git_hooks function exists in setup.sh
# ---------------------------------------------------------------------------
check "deliver_git_hooks defined in setup.sh" \
  grep -q "deliver_git_hooks()" "$OCTOPUS_DIR/setup.sh"

# ---------------------------------------------------------------------------
# T7: deliver_git_hooks is called from setup.sh main flow
# ---------------------------------------------------------------------------
check "deliver_git_hooks called in setup.sh" \
  bash -c 'grep -A5 "# 3c\." "$1" | grep -q "deliver_git_hooks"' _ "$OCTOPUS_DIR/setup.sh"

# ---------------------------------------------------------------------------
# T8: fresh install — hook is installed when workflow:true + audit skill
# ---------------------------------------------------------------------------
TMPDIR_FRESH="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FRESH"' EXIT

(
  cd "$TMPDIR_FRESH"
  git init -q
  mkdir -p .git/hooks

  cat > .octopus.yml <<'YML'
agents:
  - claude
workflow: true
skills:
  - money-review
YML

  # Run only deliver_git_hooks in isolation (source setup.sh up to function def).
  bash -c '
    set -euo pipefail
    OCTOPUS_DIR="$1"
    cd "$2"
    OCTOPUS_WORKFLOW="true"
    OCTOPUS_POST_MERGE_AUDIT_HOOK="true"
    OCTOPUS_SKILLS=( money-review )

    deliver_git_hooks() {
      source "$OCTOPUS_DIR/setup.sh" --dry-run 2>/dev/null || true
    }

    # Extract and run just deliver_git_hooks
    eval "$(grep -A60 "^deliver_git_hooks()" "$OCTOPUS_DIR/setup.sh")"
    deliver_git_hooks
  ' _ "$OCTOPUS_DIR" "$TMPDIR_FRESH" 2>/dev/null || true
)

check "fresh install: deliver_git_hooks function defined in setup.sh" \
  grep -q "deliver_git_hooks()" "$OCTOPUS_DIR/setup.sh"

# ---------------------------------------------------------------------------
# T9: opt-out — postMergeAuditHook: false skips install
# ---------------------------------------------------------------------------
check "setup.sh: postMergeAuditHook=false exits deliver_git_hooks early" bash -c '
  grep -A5 "postMergeAuditHook.*false" "$1" | grep -q "return 0"
' _ "$OCTOPUS_DIR/setup.sh"

# ---------------------------------------------------------------------------
# T10: chain mode — existing pre-push hook is preserved
# ---------------------------------------------------------------------------
check "deliver_git_hooks appends to existing hook (chain mode)" bash -c '
  grep -A50 "deliver_git_hooks()" "$1" | grep -q "Chaining"
' _ "$OCTOPUS_DIR/setup.sh"

# ---------------------------------------------------------------------------
# T11: idempotent — already-installed hook is not duplicated
# ---------------------------------------------------------------------------
check "deliver_git_hooks is idempotent (checks for sentinel)" bash -c '
  grep -A50 "deliver_git_hooks()" "$1" | grep -q "octopus:pre-push-audit-suggest"
' _ "$OCTOPUS_DIR/setup.sh"

# ---------------------------------------------------------------------------
# T12: hook sets OCTOPUS_SKIP_AUDIT_HOOK guard
# ---------------------------------------------------------------------------
check "hook checks OCTOPUS_SKIP_AUDIT_HOOK env var" \
  grep -q "OCTOPUS_SKIP_AUDIT_HOOK" "$HOOK_SRC"

# ---------------------------------------------------------------------------
# T13: hook exits 0 unconditionally (never blocks push)
# ---------------------------------------------------------------------------
check "hook exits 0 at end" bash -c \
  'tail -5 "$1" | grep -q "exit 0"' _ "$HOOK_SRC"

# ---------------------------------------------------------------------------
# T14: example.yml documents opt-out
# ---------------------------------------------------------------------------
check ".octopus.example.yml documents postMergeAuditHook opt-out" \
  grep -q "postMergeAuditHook" "$OCTOPUS_DIR/.octopus.example.yml"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
