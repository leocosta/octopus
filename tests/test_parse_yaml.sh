#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

# Create temp test config
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/.octopus.yml" << 'EOF'
stacks:
  - node
  - nextjs

agents:
  - claude
  - copilot
  - name: antigravity
    output: CUSTOM.md

mcp:
  - notion
  - github
EOF

# Test parsing
parse_octopus_yml "$TMPDIR/.octopus.yml"

# Verify stacks
[[ "${OCTOPUS_STACKS[0]}" == "node" ]] || { echo "FAIL: stacks[0] expected 'node', got '${OCTOPUS_STACKS[0]}'"; exit 1; }
[[ "${OCTOPUS_STACKS[1]}" == "nextjs" ]] || { echo "FAIL: stacks[1] expected 'nextjs', got '${OCTOPUS_STACKS[1]}'"; exit 1; }

# Verify agents
[[ "${OCTOPUS_AGENTS[0]}" == "claude" ]] || { echo "FAIL: agents[0] expected 'claude', got '${OCTOPUS_AGENTS[0]}'"; exit 1; }
[[ "${OCTOPUS_AGENTS[1]}" == "copilot" ]] || { echo "FAIL: agents[1] expected 'copilot', got '${OCTOPUS_AGENTS[1]}'"; exit 1; }
[[ "${OCTOPUS_AGENTS[2]}" == "antigravity" ]] || { echo "FAIL: agents[2] expected 'antigravity', got '${OCTOPUS_AGENTS[2]}'"; exit 1; }

# Verify custom output
[[ "${OCTOPUS_AGENT_OUTPUT[antigravity]}" == "CUSTOM.md" ]] || { echo "FAIL: antigravity output expected 'CUSTOM.md', got '${OCTOPUS_AGENT_OUTPUT[antigravity]}'"; exit 1; }

# Verify MCP
[[ "${OCTOPUS_MCP[0]}" == "notion" ]] || { echo "FAIL: mcp[0] expected 'notion', got '${OCTOPUS_MCP[0]}'"; exit 1; }
[[ "${OCTOPUS_MCP[1]}" == "github" ]] || { echo "FAIL: mcp[1] expected 'github', got '${OCTOPUS_MCP[1]}'"; exit 1; }

# Test empty array syntax
OCTOPUS_STACKS=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()
cat > "$TMPDIR/.octopus-empty.yml" << 'EOF'
stacks:
  - node
agents:
  - claude
mcp: []
EOF
parse_octopus_yml "$TMPDIR/.octopus-empty.yml"
[[ ${#OCTOPUS_MCP[@]} -eq 0 ]] || { echo "FAIL: mcp should be empty for '[]' syntax, got ${#OCTOPUS_MCP[@]}"; exit 1; }
[[ "${OCTOPUS_STACKS[0]}" == "node" ]] || { echo "FAIL: stacks should still parse with empty mcp"; exit 1; }

# --- Test: new constructs (workflow, roles, reviewers, context) ---
echo "Test: new YAML constructs"

OCTOPUS_STACKS=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()
OCTOPUS_CMD_NAMES=()
OCTOPUS_CMD_DESCS=()
OCTOPUS_CMD_RUNS=()
OCTOPUS_WORKFLOW=false
OCTOPUS_ROLES=()
OCTOPUS_REVIEWERS=()
OCTOPUS_CONTEXT=""

TMPDIR2=$(mktemp -d)
cat > "$TMPDIR2/.octopus.yml" << 'EOF'
stacks:
  - node

agents:
  - claude

mcp: []

workflow: true

reviewers:
  - user1
  - user2

roles:
  - agilista
  - fullstack-dev

context: docs/project-context.md

commands:
  - name: db-reset
    description: Reset the database
    run: make db-reset
EOF

parse_octopus_yml "$TMPDIR2/.octopus.yml"

[[ "$OCTOPUS_WORKFLOW" == "true" ]] || { echo "FAIL: workflow expected 'true', got '$OCTOPUS_WORKFLOW'"; exit 1; }
[[ "${OCTOPUS_REVIEWERS[0]}" == "user1" ]] || { echo "FAIL: reviewers[0] expected 'user1', got '${OCTOPUS_REVIEWERS[0]}'"; exit 1; }
[[ "${OCTOPUS_REVIEWERS[1]}" == "user2" ]] || { echo "FAIL: reviewers[1] expected 'user2', got '${OCTOPUS_REVIEWERS[1]}'"; exit 1; }
[[ "${OCTOPUS_ROLES[0]}" == "agilista" ]] || { echo "FAIL: roles[0] expected 'agilista', got '${OCTOPUS_ROLES[0]}'"; exit 1; }
[[ "${OCTOPUS_ROLES[1]}" == "fullstack-dev" ]] || { echo "FAIL: roles[1] expected 'fullstack-dev', got '${OCTOPUS_ROLES[1]}'"; exit 1; }
[[ "$OCTOPUS_CONTEXT" == "docs/project-context.md" ]] || { echo "FAIL: context expected 'docs/project-context.md', got '$OCTOPUS_CONTEXT'"; exit 1; }
[[ "${OCTOPUS_CMD_NAMES[0]}" == "db-reset" ]] || { echo "FAIL: commands still work after new constructs"; exit 1; }

# Test workflow: false
OCTOPUS_WORKFLOW=false
OCTOPUS_ROLES=()
OCTOPUS_REVIEWERS=()
OCTOPUS_CONTEXT=""
cat > "$TMPDIR2/.octopus2.yml" << 'EOF'
stacks:
  - node
agents:
  - claude
workflow: false
roles: []
EOF

parse_octopus_yml "$TMPDIR2/.octopus2.yml"
[[ "$OCTOPUS_WORKFLOW" == "false" ]] || { echo "FAIL: workflow should be 'false'"; exit 1; }
[[ ${#OCTOPUS_ROLES[@]} -eq 0 ]] || { echo "FAIL: roles should be empty"; exit 1; }

# Test defaults (no workflow/roles/context lines)
OCTOPUS_WORKFLOW=false
OCTOPUS_CONTEXT=""
OCTOPUS_ROLES=()
OCTOPUS_REVIEWERS=()
cat > "$TMPDIR2/.octopus3.yml" << 'EOF'
stacks:
  - node
agents:
  - claude
EOF

parse_octopus_yml "$TMPDIR2/.octopus3.yml"
[[ "$OCTOPUS_WORKFLOW" == "false" ]] || { echo "FAIL: workflow should default to 'false'"; exit 1; }
[[ "$OCTOPUS_CONTEXT" == "" ]] || { echo "FAIL: context should default to empty"; exit 1; }
[[ ${#OCTOPUS_ROLES[@]} -eq 0 ]] || { echo "FAIL: roles should default to empty"; exit 1; }

rm -rf "$TMPDIR2"
echo "PASS: new YAML constructs parsed correctly"

# --- Test: rules, skills, hooks parsing ---
echo "Test: rules/skills/hooks YAML constructs"

OCTOPUS_STACKS=()
OCTOPUS_RULES=()
OCTOPUS_SKILLS=()
OCTOPUS_HOOKS="false"
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()
OCTOPUS_CMD_NAMES=()
OCTOPUS_CMD_DESCS=()
OCTOPUS_CMD_RUNS=()
OCTOPUS_WORKFLOW=false
OCTOPUS_ROLES=()
OCTOPUS_REVIEWERS=()
OCTOPUS_CONTEXT=""

TMPDIR3=$(mktemp -d)
cat > "$TMPDIR3/.octopus.yml" << 'EOF'
rules:
  - csharp
  - typescript

skills:
  - adr
  - e2e-testing
  - backend-patterns

hooks: true

agents:
  - claude
EOF

parse_octopus_yml "$TMPDIR3/.octopus.yml"

[[ "${OCTOPUS_RULES[0]}" == "csharp" ]] || { echo "FAIL: rules[0] expected 'csharp', got '${OCTOPUS_RULES[0]}'"; exit 1; }
[[ "${OCTOPUS_RULES[1]}" == "typescript" ]] || { echo "FAIL: rules[1] expected 'typescript', got '${OCTOPUS_RULES[1]}'"; exit 1; }
[[ "${OCTOPUS_SKILLS[0]}" == "adr" ]] || { echo "FAIL: skills[0] expected 'adr', got '${OCTOPUS_SKILLS[0]}'"; exit 1; }
[[ "${OCTOPUS_SKILLS[1]}" == "e2e-testing" ]] || { echo "FAIL: skills[1] expected 'e2e-testing', got '${OCTOPUS_SKILLS[1]}'"; exit 1; }
[[ "${OCTOPUS_SKILLS[2]}" == "backend-patterns" ]] || { echo "FAIL: skills[2] expected 'backend-patterns', got '${OCTOPUS_SKILLS[2]}'"; exit 1; }
[[ "$OCTOPUS_HOOKS" == "true" ]] || { echo "FAIL: hooks expected 'true', got '$OCTOPUS_HOOKS'"; exit 1; }

rm -rf "$TMPDIR3"
echo "PASS: rules/skills/hooks parsed correctly"

# --- Test: stacks-to-rules migration ---
echo "Test: stacks-to-rules migration"

OCTOPUS_STACKS=(node dotnet react)
OCTOPUS_RULES=()

migrate_stacks_to_rules

[[ "${OCTOPUS_RULES[0]}" == "common" ]] || { echo "FAIL: rules[0] should be 'common', got '${OCTOPUS_RULES[0]}'"; exit 1; }
# node and react both map to typescript, should be deduplicated
found_typescript=0
found_csharp=0
for r in "${OCTOPUS_RULES[@]}"; do
  [[ "$r" == "typescript" ]] && found_typescript=$((found_typescript + 1))
  [[ "$r" == "csharp" ]] && found_csharp=$((found_csharp + 1))
done
[[ $found_typescript -eq 1 ]] || { echo "FAIL: typescript should appear once, got $found_typescript"; exit 1; }
[[ $found_csharp -eq 1 ]] || { echo "FAIL: csharp should appear once, got $found_csharp"; exit 1; }

echo "PASS: stacks-to-rules migration works"

# --- Test: common always included ---
echo "Test: common always included"

OCTOPUS_STACKS=()
OCTOPUS_RULES=(csharp)

migrate_stacks_to_rules

[[ "${OCTOPUS_RULES[0]}" == "common" ]] || { echo "FAIL: common should be prepended, got '${OCTOPUS_RULES[0]}'"; exit 1; }
[[ "${OCTOPUS_RULES[1]}" == "csharp" ]] || { echo "FAIL: csharp should be second, got '${OCTOPUS_RULES[1]}'"; exit 1; }

echo "PASS: common always included"

rm -rf "$TMPDIR"
echo "PASS: all YAML parsing tests passed"
