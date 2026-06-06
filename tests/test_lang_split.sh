#!/usr/bin/env bash
# tests/test_lang_split.sh
# RM-120/127 — lang-split + bundle-per-stack guarantees.
#
# Language rules and intent bundles are ORTHOGONAL axes by design:
#   - `rules:` (a language axis: common/csharp/python/typescript) controls
#     which rule sets load — only the declared stack's, never all languages.
#   - bundles (an intent axis: backend/frontend/...) control which
#     skills/roles are delivered — only what the repo's intent needs.
# These tests lock both guarantees so a future change can't silently start
# loading every language's rules or every skill into every repo. Grep/exit-code
# assertions, per project convention.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@" &>/dev/null; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

# --- lang-split: only the declared stack's rules are delivered (RM-120) -----
TMP=$(mktemp -d); PROJECT_ROOT="$TMP"; OCTOPUS_DIR="$SCRIPT_DIR"
OCTOPUS_RULES=(common typescript); OCTOPUS_SKILLS=(); OCTOPUS_AGENTS=(claude)
declare -A OCTOPUS_AGENT_OUTPUT=()
load_manifest claude
deliver_rules claude >/dev/null 2>&1

check "common rules delivered"      test -d "$TMP/.claude/rules/common"
check "declared stack (typescript) delivered" test -d "$TMP/.claude/rules/typescript"
check "undeclared stack csharp NOT delivered" test ! -e "$TMP/.claude/rules/csharp"
check "undeclared stack python NOT delivered" test ! -e "$TMP/.claude/rules/python"
rm -rf "$TMP"

# --- bundle-per-stack: an intent bundle delivers only its skills (RM-127) ---
# The backend bundle must not pull frontend-only skills into a backend repo.
backend_skills="$(grep -A40 '^skills:' "$SCRIPT_DIR/bundles/backend.yml" | sed -n 's/^  - \([a-z-]*\).*/\1/p')"
check "backend bundle includes backend-patterns" grep -q 'backend-patterns' <<<"$backend_skills"
check "backend bundle excludes frontend-patterns" bash -c "! grep -q 'frontend-patterns' <<<\"$backend_skills\""
check "backend bundle excludes test-component"    bash -c "! grep -q 'test-component' <<<\"$backend_skills\""

# --- empty-prune: a manifest that dropped all skills/rules must not leave -----
# stale symlinks behind. deliver_skills/deliver_rules wipe-and-rebuild the
# target even when the set is empty (no early-return). Regression: 60 stale
# symlinks lingered in repos because deliver_skills used to early-return on
# an empty OCTOPUS_SKILLS.
TMP=$(mktemp -d); PROJECT_ROOT="$TMP"; OCTOPUS_DIR="$SCRIPT_DIR"
OCTOPUS_AGENTS=(claude); declare -A OCTOPUS_AGENT_OUTPUT=()
load_manifest claude
# seed a stale symlink in each target as if a previous setup left it
mkdir -p "$TMP/.claude/skills" "$TMP/.claude/rules"
ln -s /tmp/gone "$TMP/.claude/skills/ghost-skill"
ln -s /tmp/gone "$TMP/.claude/rules/ghost-rule"

OCTOPUS_SKILLS=(); OCTOPUS_RULES=()
deliver_skills claude >/dev/null 2>&1
deliver_rules  claude >/dev/null 2>&1

check "empty skills prunes stale symlink" test ! -e "$TMP/.claude/skills/ghost-skill"
check "empty skills prunes broken symlink" bash -c "! find '$TMP/.claude/skills' -name ghost-skill | grep -q ."
check "empty rules prunes stale symlink"  test ! -e "$TMP/.claude/rules/ghost-rule"
check "empty rules prunes broken symlink"  bash -c "! find '$TMP/.claude/rules' -name ghost-rule | grep -q ."
rm -rf "$TMP"

echo "-----------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
