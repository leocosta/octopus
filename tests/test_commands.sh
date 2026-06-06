#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Test 1: Parse commands from YAML ---
echo "Test 1: Parse commands from YAML"

source "$SCRIPT_DIR/setup.sh" --source-only

WORKDIR=$(mktemp -d)
cat > "$WORKDIR/test.yml" << 'EOF'
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

parse_octopus_yml "$WORKDIR/test.yml"

[[ ${#OCTOPUS_CMD_NAMES[@]} -eq 2 ]] || { echo "FAIL: expected 2 commands, got ${#OCTOPUS_CMD_NAMES[@]}"; exit 1; }
[[ "${OCTOPUS_CMD_NAMES[0]}" == "db-reset" ]] || { echo "FAIL: first command name"; exit 1; }
[[ "${OCTOPUS_CMD_DESCS[0]}" == "Reset the database" ]] || { echo "FAIL: first command desc"; exit 1; }
[[ "${OCTOPUS_CMD_RUNS[0]}" == "make db-reset" ]] || { echo "FAIL: first command run"; exit 1; }
[[ "${OCTOPUS_CMD_NAMES[1]}" == "db-migration" ]] || { echo "FAIL: second command name"; exit 1; }
[[ "${OCTOPUS_CMD_RUNS[1]}" == 'make db-migration NAME=$ARGUMENTS' ]] || { echo "FAIL: second command run"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: commands parsed correctly"

# --- Test 2: Parse empty commands ---
echo "Test 2: Parse empty commands"

OCTOPUS_CMD_NAMES=()
OCTOPUS_CMD_DESCS=()
OCTOPUS_CMD_RUNS=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()

WORKDIR=$(mktemp -d)
cat > "$WORKDIR/test.yml" << 'EOF'
agents:
  - claude
commands: []
EOF

parse_octopus_yml "$WORKDIR/test.yml"

[[ ${#OCTOPUS_CMD_NAMES[@]} -eq 0 ]] || { echo "FAIL: expected 0 commands, got ${#OCTOPUS_CMD_NAMES[@]}"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: empty commands handled"

# --- Test 3: Generate Claude slash command files ---
echo "Test 3: Generate Claude slash command files"

OCTOPUS_AGENTS=(claude)
OCTOPUS_CMD_NAMES=(db-reset db-migration)
OCTOPUS_CMD_DESCS=("Reset the database" "Add a new migration")
OCTOPUS_CMD_RUNS=("make db-reset" 'make db-migration NAME=$ARGUMENTS')

WORKDIR=$(mktemp -d)
PROJECT_ROOT="$WORKDIR"

mkdir -p "$WORKDIR/.claude"
agent="claude"
load_manifest "$agent"
deliver_commands "$agent"

[[ -f "$WORKDIR/.claude/commands/octopus:db-reset.md" ]] || { echo "FAIL: octopus:db-reset.md not created"; exit 1; }
[[ -f "$WORKDIR/.claude/commands/octopus:db-migration.md" ]] || { echo "FAIL: octopus:db-migration.md not created"; exit 1; }
grep -q "Reset the database" "$WORKDIR/.claude/commands/octopus:db-reset.md" || { echo "FAIL: description missing"; exit 1; }
grep -q "make db-reset" "$WORKDIR/.claude/commands/octopus:db-reset.md" || { echo "FAIL: run command missing"; exit 1; }
grep -q 'make db-migration NAME=$ARGUMENTS' "$WORKDIR/.claude/commands/octopus:db-migration.md" || { echo "FAIL: run with args missing"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: Claude slash command files generated"

# --- Test 3b: deliver_commands prunes renamed/removed Octopus commands ---
echo "Test 3b: deliver_commands prunes stale Octopus commands, keeps user ones"

# Hermetic: save the shared command globals this test mutates, restore after so
# later tests keep the db-reset + db-migration set they expect.
_b_names=("${OCTOPUS_CMD_NAMES[@]}"); _b_descs=("${OCTOPUS_CMD_DESCS[@]}")
_b_runs=("${OCTOPUS_CMD_RUNS[@]}");   _b_wf="${OCTOPUS_WORKFLOW:-}"

OCTOPUS_CMD_NAMES=(db-reset)
OCTOPUS_CMD_DESCS=("Reset the database")
OCTOPUS_CMD_RUNS=("make db-reset")
OCTOPUS_WORKFLOW=false

WORKDIR=$(mktemp -d)
PROJECT_ROOT="$WORKDIR"
mkdir -p "$WORKDIR/.claude/commands"
# stale Octopus command from a previous version (e.g. a renamed/removed one) +
# a user-authored, non-prefixed command that must survive.
echo "stale" > "$WORKDIR/.claude/commands/octopus:quality-metrics.md"
echo "mine"  > "$WORKDIR/.claude/commands/my-own.md"

agent="claude"
load_manifest "$agent"
OCTOPUS_WORKFLOW=false
deliver_commands "$agent"

[[ ! -f "$WORKDIR/.claude/commands/octopus:quality-metrics.md" ]] \
  || { echo "FAIL: stale octopus: command not pruned"; rm -rf "$WORKDIR"; exit 1; }
[[ -f "$WORKDIR/.claude/commands/my-own.md" ]] \
  || { echo "FAIL: user-authored command wrongly pruned"; rm -rf "$WORKDIR"; exit 1; }
[[ -f "$WORKDIR/.claude/commands/octopus:db-reset.md" ]] \
  || { echo "FAIL: current command not regenerated after prune"; rm -rf "$WORKDIR"; exit 1; }

rm -rf "$WORKDIR"
# restore shared globals for subsequent tests
OCTOPUS_CMD_NAMES=("${_b_names[@]}"); OCTOPUS_CMD_DESCS=("${_b_descs[@]}")
OCTOPUS_CMD_RUNS=("${_b_runs[@]}");   OCTOPUS_WORKFLOW="$_b_wf"
echo "PASS: stale Octopus commands pruned, user commands kept"

# --- Test 4: Commands section appended to concatenation agents ---
echo "Test 4: Commands section in concatenated output"

WORKDIR=$(mktemp -d)
echo "# Test" > "$WORKDIR/output.md"
append_commands_section "$WORKDIR/output.md"

grep -q "# Custom Project Commands" "$WORKDIR/output.md" || { echo "FAIL: commands section missing"; exit 1; }
grep -q "/octopus:db-reset" "$WORKDIR/output.md" || { echo "FAIL: db-reset command missing"; exit 1; }
grep -q "/octopus:db-migration" "$WORKDIR/output.md" || { echo "FAIL: db-migration command missing"; exit 1; }
grep -q "make db-reset" "$WORKDIR/output.md" || { echo "FAIL: run command missing from section"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: commands section appended correctly"

# --- Test 5: No commands section when empty ---
echo "Test 5: No commands section when empty"

OCTOPUS_CMD_NAMES=()
OCTOPUS_CMD_DESCS=()
OCTOPUS_CMD_RUNS=()

WORKDIR=$(mktemp -d)
echo "# Test" > "$WORKDIR/output.md"
append_commands_section "$WORKDIR/output.md"

! grep -q "Project Commands" "$WORKDIR/output.md" || { echo "FAIL: commands section should not appear"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: no commands section when empty"

echo ""
echo "All command tests passed!"
