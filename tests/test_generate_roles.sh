#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

OCTOPUS_ROLES=(product-manager)
OCTOPUS_AGENTS=(claude copilot)
declare -A OCTOPUS_AGENT_OUTPUT=()

# --- Test 1: Claude gets native agent file ---
echo "Test 1: Claude role generation"

generate_roles

[[ -f "$TMPDIR/.claude/agents/product-manager.md" ]] || { echo "FAIL: .claude/agents/product-manager.md not created"; exit 1; }

# Verify frontmatter preserved
grep -q "^name: product-manager" "$TMPDIR/.claude/agents/product-manager.md" || { echo "FAIL: frontmatter name missing"; exit 1; }
grep -q "^model: sonnet" "$TMPDIR/.claude/agents/product-manager.md" || { echo "FAIL: frontmatter model missing"; exit 1; }

# Verify PROJECT_CONTEXT placeholder was replaced (with empty string when no knowledge modules)
! grep -q "{{PROJECT_CONTEXT}}" "$TMPDIR/.claude/agents/product-manager.md" || { echo "FAIL: {{PROJECT_CONTEXT}} placeholder not replaced"; exit 1; }

# Verify _base.md content injected
grep -q "General Guidelines" "$TMPDIR/.claude/agents/product-manager.md" || { echo "FAIL: _base.md not injected"; exit 1; }

echo "PASS: Claude role generation"

# --- Test 2: Copilot gets concatenated section ---
echo "Test 2: Copilot role section"

# First generate the copilot config (so there's a file to append to)
OCTOPUS_CMD_NAMES=()
concatenate_agent "copilot"

generate_roles

OUTPUT="$TMPDIR/.github/copilot-instructions.md"
grep -q "# Role: Product-manager" "$OUTPUT" || { echo "FAIL: role section header missing from copilot"; exit 1; }
# Verify no frontmatter fields in copilot output (don't check --- since copilot header has it as separator)
! grep -q "^name: product-manager" "$OUTPUT" || { echo "FAIL: frontmatter name leaked into copilot"; exit 1; }
! grep -q "^model: sonnet" "$OUTPUT" || { echo "FAIL: frontmatter model leaked into copilot"; exit 1; }

echo "PASS: Copilot role section"

rm -rf "$TMPDIR"
echo "PASS: all role generation tests passed"
