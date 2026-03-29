#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Test 1: Parse commands from YAML ---
echo "Test 1: Parse commands from YAML"

source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
cat > "$TMPDIR/test.yml" << 'EOF'
agents:
  - claude
  - copilot

commands:
  - name: db-reset
    description: Reset the database
    run: make db-reset
  - name: db-migration
    description: Add a new migration
    run: make db-migration NAME=$ARGUMENTS
EOF

parse_octopus_yml "$TMPDIR/test.yml"

[[ ${#OCTOPUS_CMD_NAMES[@]} -eq 2 ]] || { echo "FAIL: expected 2 commands, got ${#OCTOPUS_CMD_NAMES[@]}"; exit 1; }
[[ "${OCTOPUS_CMD_NAMES[0]}" == "db-reset" ]] || { echo "FAIL: first command name"; exit 1; }
[[ "${OCTOPUS_CMD_DESCS[0]}" == "Reset the database" ]] || { echo "FAIL: first command desc"; exit 1; }
[[ "${OCTOPUS_CMD_RUNS[0]}" == "make db-reset" ]] || { echo "FAIL: first command run"; exit 1; }
[[ "${OCTOPUS_CMD_NAMES[1]}" == "db-migration" ]] || { echo "FAIL: second command name"; exit 1; }
[[ "${OCTOPUS_CMD_RUNS[1]}" == 'make db-migration NAME=$ARGUMENTS' ]] || { echo "FAIL: second command run"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: commands parsed correctly"

# --- Test 2: Parse empty commands ---
echo "Test 2: Parse empty commands"

OCTOPUS_CMD_NAMES=()
OCTOPUS_CMD_DESCS=()
OCTOPUS_CMD_RUNS=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()

TMPDIR=$(mktemp -d)
cat > "$TMPDIR/test.yml" << 'EOF'
agents:
  - claude
commands: []
EOF

parse_octopus_yml "$TMPDIR/test.yml"

[[ ${#OCTOPUS_CMD_NAMES[@]} -eq 0 ]] || { echo "FAIL: expected 0 commands, got ${#OCTOPUS_CMD_NAMES[@]}"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: empty commands handled"

# --- Test 3: Generate Claude slash command files ---
echo "Test 3: Generate Claude slash command files"

OCTOPUS_AGENTS=(claude)
OCTOPUS_CMD_NAMES=(db-reset db-migration)
OCTOPUS_CMD_DESCS=("Reset the database" "Add a new migration")
OCTOPUS_CMD_RUNS=("make db-reset" 'make db-migration NAME=$ARGUMENTS')

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"

mkdir -p "$TMPDIR/.claude"
generate_commands

[[ -f "$TMPDIR/.claude/commands/octopus:db-reset.md" ]] || { echo "FAIL: octopus:db-reset.md not created"; exit 1; }
[[ -f "$TMPDIR/.claude/commands/octopus:db-migration.md" ]] || { echo "FAIL: octopus:db-migration.md not created"; exit 1; }
grep -q "Reset the database" "$TMPDIR/.claude/commands/octopus:db-reset.md" || { echo "FAIL: description missing"; exit 1; }
grep -q "make db-reset" "$TMPDIR/.claude/commands/octopus:db-reset.md" || { echo "FAIL: run command missing"; exit 1; }
grep -q 'make db-migration NAME=$ARGUMENTS' "$TMPDIR/.claude/commands/octopus:db-migration.md" || { echo "FAIL: run with args missing"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: Claude slash command files generated"

# --- Test 4: Commands section appended to concatenation agents ---
echo "Test 4: Commands section in concatenated output"

TMPDIR=$(mktemp -d)
echo "# Test" > "$TMPDIR/output.md"
append_commands_section "$TMPDIR/output.md"

grep -q "# Custom Project Commands" "$TMPDIR/output.md" || { echo "FAIL: commands section missing"; exit 1; }
grep -q "/octopus:db-reset" "$TMPDIR/output.md" || { echo "FAIL: db-reset command missing"; exit 1; }
grep -q "/octopus:db-migration" "$TMPDIR/output.md" || { echo "FAIL: db-migration command missing"; exit 1; }
grep -q "make db-reset" "$TMPDIR/output.md" || { echo "FAIL: run command missing from section"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: commands section appended correctly"

# --- Test 5: No commands section when empty ---
echo "Test 5: No commands section when empty"

OCTOPUS_CMD_NAMES=()
OCTOPUS_CMD_DESCS=()
OCTOPUS_CMD_RUNS=()

TMPDIR=$(mktemp -d)
echo "# Test" > "$TMPDIR/output.md"
append_commands_section "$TMPDIR/output.md"

! grep -q "Project Commands" "$TMPDIR/output.md" || { echo "FAIL: commands section should not appear"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: no commands section when empty"

echo ""
echo "All command tests passed!"
