#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$SCRIPT_DIR/setup.sh"

echo "Test 1: _dry_run_log helper defined in setup.sh"
grep -q "_dry_run_log()" "$SETUP" \
  || { echo "FAIL: _dry_run_log() missing from setup.sh"; exit 1; }
echo "PASS"

echo "Test 2: OCTOPUS_DRY_RUN guard present in deliver_rules"
grep -q "OCTOPUS_DRY_RUN.*deliver_rules\|deliver_rules.*OCTOPUS_DRY_RUN\|would symlink rules" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_rules"; exit 1; }
echo "PASS"

echo "Test 3: OCTOPUS_DRY_RUN guard present in deliver_skills"
grep -q "would symlink skills" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_skills"; exit 1; }
echo "PASS"

echo "Test 4: OCTOPUS_DRY_RUN guard present in deliver_hooks"
grep -q "would merge hooks" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_hooks"; exit 1; }
echo "PASS"

echo "Test 5: OCTOPUS_DRY_RUN guard present in deliver_permissions"
grep -q "would merge permissions" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_permissions"; exit 1; }
echo "PASS"

echo "Test 6: OCTOPUS_DRY_RUN guard present in deliver_roles"
grep -q "would deliver roles" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_roles"; exit 1; }
echo "PASS"

echo "Test 7: OCTOPUS_DRY_RUN guard present in deliver_commands"
grep -q "would deliver commands" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_commands"; exit 1; }
echo "PASS"

echo "Test 8: OCTOPUS_DRY_RUN guard present in deliver_mcp"
grep -q "would inject MCP servers" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_mcp"; exit 1; }
echo "PASS"

echo "Test 9: OCTOPUS_DRY_RUN guard present in deliver_github_action"
grep -q "would scaffold .github/workflows/claude.yml" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_github_action"; exit 1; }
echo "PASS"

echo "Test 10: OCTOPUS_DRY_RUN guard present in deliver_dream_subagent"
grep -q "would copy dream subagent" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_dream_subagent"; exit 1; }
echo "PASS"

echo "Test 11: OCTOPUS_DRY_RUN guard present in deliver_boris_settings"
grep -q "would inject boris-tip settings" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_boris_settings"; exit 1; }
echo "PASS"

echo "Test 12: OCTOPUS_DRY_RUN guard present in deliver_git_hooks"
grep -q "would install pre-push audit-suggest hook" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from deliver_git_hooks"; exit 1; }
echo "PASS"

echo "Test 13: OCTOPUS_DRY_RUN guard present in manage_env"
grep -q "would create .env.octopus" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from manage_env"; exit 1; }
echo "PASS"

echo "Test 14: OCTOPUS_DRY_RUN guard present in update_gitignore"
grep -q "would update .gitignore" "$SETUP" \
  || { echo "FAIL: dry-run guard missing from update_gitignore"; exit 1; }
echo "PASS"

echo "Test 15: --dry-run flag parsed in cli/lib/setup.sh"
grep -q "OCTOPUS_DRY_RUN" "$SCRIPT_DIR/cli/lib/setup.sh" \
  || { echo "FAIL: --dry-run flag not parsed in cli/lib/setup.sh"; exit 1; }
echo "PASS"

# Integration test: dry-run produces no files
echo "Test 16: dry-run produces no files in a temp project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Minimal .octopus.yml
cat > "$TMP_DIR/.octopus.yml" << 'YML'
agents:
  - claude
bundles:
  - core
workflow: false
YML

cd "$TMP_DIR" && git init -q && git config user.email "test@test.com" && git config user.name "Test"

OCTOPUS_DIR="$SCRIPT_DIR" \
OCTOPUS_DRY_RUN=true \
PROJECT_ROOT="$TMP_DIR" \
  bash "$SETUP" > /dev/null 2>&1 || true

# No .claude directory should have been created
if [[ -d "$TMP_DIR/.claude" ]]; then
  echo "FAIL: .claude/ was created during dry-run"
  exit 1
fi
echo "PASS"

echo ""
echo "All dry-run tests passed."
