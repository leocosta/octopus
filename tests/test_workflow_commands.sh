#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

# --- Test 1: workflow: true generates Claude slash commands ---
echo "Test 1: Workflow commands for Claude"

OCTOPUS_AGENTS=(claude)
OCTOPUS_WORKFLOW=true
declare -A OCTOPUS_AGENT_OUTPUT=()

mkdir -p "$TMPDIR/.claude"
load_manifest "claude"
deliver_commands "claude"

[[ -f "$TMPDIR/.claude/commands/octopus:branch-create.md" ]] || { echo "FAIL: octopus:branch-create.md not created"; exit 1; }
[[ -f "$TMPDIR/.claude/commands/octopus:pr-open.md" ]] || { echo "FAIL: octopus:pr-open.md not created"; exit 1; }
[[ -f "$TMPDIR/.claude/commands/octopus:pr-review.md" ]] || { echo "FAIL: octopus:pr-review.md not created"; exit 1; }
[[ -f "$TMPDIR/.claude/commands/octopus:pr-comments.md" ]] || { echo "FAIL: octopus:pr-comments.md not created"; exit 1; }
[[ -f "$TMPDIR/.claude/commands/octopus:pr-merge.md" ]] || { echo "FAIL: octopus:pr-merge.md not created"; exit 1; }
[[ -f "$TMPDIR/.claude/commands/octopus:dev-flow.md" ]] || { echo "FAIL: octopus:dev-flow.md not created"; exit 1; }
[[ -f "$TMPDIR/.claude/commands/octopus:release.md" ]] || { echo "FAIL: octopus:release.md not created"; exit 1; }

# Command templates carry TWO frontmatter blocks in source: the outer one
# holds Octopus metadata (name:, cli:) that must be stripped, and the inner
# one is a Claude-readable slash-command header (description:, agent:) that
# the delivered file must keep. Verify only the Octopus-specific fields are
# gone — presence of the inner block (and its leading ---) is correct.
! grep -Eq "^(name|cli):" "$TMPDIR/.claude/commands/octopus:pr-open.md" \
  || { echo "FAIL: Octopus frontmatter fields leaked into body"; exit 1; }
# Verify content has instructions
grep -q "Instructions" "$TMPDIR/.claude/commands/octopus:pr-open.md" || { echo "FAIL: instructions missing"; exit 1; }

echo "PASS: workflow commands for Claude"

# --- Test 2: workflow: false generates nothing ---
echo "Test 2: Workflow disabled"

rm -rf "$TMPDIR/.claude/commands"
OCTOPUS_WORKFLOW=false
mkdir -p "$TMPDIR/.claude"

load_manifest "claude"
deliver_commands "claude"

[[ ! -f "$TMPDIR/.claude/commands/octopus:branch-create.md" ]] || { echo "FAIL: should not generate when workflow is false"; exit 1; }

echo "PASS: workflow disabled"

# --- Test 3: Copilot gets concatenated commands section ---
echo "Test 3: Workflow commands for copilot"

OCTOPUS_WORKFLOW=true
OCTOPUS_AGENTS=(copilot)
OCTOPUS_CMD_NAMES=()

load_manifest "copilot"
generate_main_output "copilot"
deliver_commands "copilot"

OUTPUT="$TMPDIR/.github/copilot-instructions.md"
grep -q "# Octopus Commands" "$OUTPUT" || { echo "FAIL: Octopus Commands section missing"; exit 1; }
grep -q "/octopus:branch-create" "$OUTPUT" || { echo "FAIL: branch-create missing from copilot"; exit 1; }
grep -q "/octopus:pr-open" "$OUTPUT" || { echo "FAIL: pr-open missing from copilot"; exit 1; }
# RM-007 renamed the CLI from `octopus.sh` to the global `octopus` shim.
grep -Eq "Run: \`octopus (branch-create|pr-open|release)\`" "$OUTPUT" \
  || { echo "FAIL: CLI reference missing from copilot"; exit 1; }

echo "PASS: workflow commands for copilot"

rm -rf "$TMPDIR"
echo "PASS: all workflow command tests passed"
