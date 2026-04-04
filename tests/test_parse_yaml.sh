#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

# Create temp test config
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/.octopus.yml" << 'EOF'
rules:
  - typescript
  - node

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

# Verify rules
[[ "${OCTOPUS_RULES[0]}" == "typescript" ]] || { echo "FAIL: rules[0] expected 'typescript', got '${OCTOPUS_RULES[0]}'"; exit 1; }
[[ "${OCTOPUS_RULES[1]}" == "node" ]] || { echo "FAIL: rules[1] expected 'node', got '${OCTOPUS_RULES[1]}'"; exit 1; }

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
OCTOPUS_RULES=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()
cat > "$TMPDIR/.octopus-empty.yml" << 'EOF'
rules:
  - typescript
agents:
  - claude
mcp: []
EOF
parse_octopus_yml "$TMPDIR/.octopus-empty.yml"
[[ ${#OCTOPUS_MCP[@]} -eq 0 ]] || { echo "FAIL: mcp should be empty for '[]' syntax, got ${#OCTOPUS_MCP[@]}"; exit 1; }
[[ "${OCTOPUS_RULES[0]}" == "typescript" ]] || { echo "FAIL: rules should still parse with empty mcp"; exit 1; }

# --- Test: new constructs (workflow, roles, reviewers, context) ---
echo "Test: new YAML constructs"

OCTOPUS_RULES=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()
OCTOPUS_CMD_NAMES=()
OCTOPUS_CMD_DESCS=()
OCTOPUS_CMD_RUNS=()
OCTOPUS_WORKFLOW=false
OCTOPUS_ROLES=()
OCTOPUS_REVIEWERS=()

TMPDIR2=$(mktemp -d)
cat > "$TMPDIR2/.octopus.yml" << 'EOF'
rules:
  - typescript

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
[[ "${OCTOPUS_CMD_NAMES[0]}" == "db-reset" ]] || { echo "FAIL: commands still work after new constructs"; exit 1; }

# Test workflow: false
OCTOPUS_WORKFLOW=false
OCTOPUS_ROLES=()
OCTOPUS_REVIEWERS=()
cat > "$TMPDIR2/.octopus2.yml" << 'EOF'
agents:
  - claude
workflow: false
roles: []
EOF

parse_octopus_yml "$TMPDIR2/.octopus2.yml"
[[ "$OCTOPUS_WORKFLOW" == "false" ]] || { echo "FAIL: workflow should be 'false'"; exit 1; }
[[ ${#OCTOPUS_ROLES[@]} -eq 0 ]] || { echo "FAIL: roles should be empty"; exit 1; }

# Test defaults (no workflow/roles lines)
OCTOPUS_WORKFLOW=false
OCTOPUS_ROLES=()
OCTOPUS_REVIEWERS=()
cat > "$TMPDIR2/.octopus3.yml" << 'EOF'
agents:
  - claude
EOF

parse_octopus_yml "$TMPDIR2/.octopus3.yml"
[[ "$OCTOPUS_WORKFLOW" == "false" ]] || { echo "FAIL: workflow should default to 'false'"; exit 1; }
[[ ${#OCTOPUS_ROLES[@]} -eq 0 ]] || { echo "FAIL: roles should default to empty"; exit 1; }

rm -rf "$TMPDIR2"
echo "PASS: new YAML constructs parsed correctly"

# --- Test: rules, skills, hooks parsing ---
echo "Test: rules/skills/hooks YAML constructs"

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

# --- Test: common always included ---
echo "Test: common always included"

OCTOPUS_RULES=(csharp)

ensure_common_rule

[[ "${OCTOPUS_RULES[0]}" == "common" ]] || { echo "FAIL: common should be prepended, got '${OCTOPUS_RULES[0]}'"; exit 1; }
[[ "${OCTOPUS_RULES[1]}" == "csharp" ]] || { echo "FAIL: csharp should be second, got '${OCTOPUS_RULES[1]}'"; exit 1; }

echo "PASS: common always included"

# --- Test: knowledge: parsing ---
echo "Test: knowledge YAML parsing"

TMPDIR4=$(mktemp -d)

# Format A: boolean
OCTOPUS_KNOWLEDGE_ENABLED="false"
OCTOPUS_KNOWLEDGE_MODE=""
OCTOPUS_KNOWLEDGE_LIST=()
OCTOPUS_KNOWLEDGE_ROLES=()
cat > "$TMPDIR4/.octopus-a.yml" << 'EOF'
agents:
  - claude
knowledge: true
EOF
parse_octopus_yml "$TMPDIR4/.octopus-a.yml"
[[ "$OCTOPUS_KNOWLEDGE_ENABLED" == "true" ]] || { echo "FAIL: Format A: KNOWLEDGE_ENABLED expected true"; exit 1; }
[[ "$OCTOPUS_KNOWLEDGE_MODE" == "auto" ]] || { echo "FAIL: Format A: KNOWLEDGE_MODE expected auto, got '$OCTOPUS_KNOWLEDGE_MODE'"; exit 1; }

# Format B: simple list
OCTOPUS_KNOWLEDGE_ENABLED="false"
OCTOPUS_KNOWLEDGE_MODE=""
OCTOPUS_KNOWLEDGE_LIST=()
OCTOPUS_KNOWLEDGE_ROLES=()
cat > "$TMPDIR4/.octopus-b.yml" << 'EOF'
agents:
  - claude
knowledge:
  - domain
  - architecture
EOF
parse_octopus_yml "$TMPDIR4/.octopus-b.yml"
[[ "$OCTOPUS_KNOWLEDGE_ENABLED" == "true" ]] || { echo "FAIL: Format B: KNOWLEDGE_ENABLED expected true"; exit 1; }
[[ "$OCTOPUS_KNOWLEDGE_MODE" == "explicit" ]] || { echo "FAIL: Format B: KNOWLEDGE_MODE expected explicit, got '$OCTOPUS_KNOWLEDGE_MODE'"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_LIST[0]}" == "domain" ]] || { echo "FAIL: Format B: list[0] expected domain"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_LIST[1]}" == "architecture" ]] || { echo "FAIL: Format B: list[1] expected architecture"; exit 1; }

# Format C: full config with modules: and roles:
OCTOPUS_KNOWLEDGE_ENABLED="false"
OCTOPUS_KNOWLEDGE_MODE=""
OCTOPUS_KNOWLEDGE_LIST=()
OCTOPUS_KNOWLEDGE_ROLES=()
cat > "$TMPDIR4/.octopus-c.yml" << 'EOF'
agents:
  - claude
knowledge:
  modules:
    - domain
    - auth
    - pricing
    - retention
  roles:
    backend-specialist:
      - domain
      - auth
    product-manager:
      - domain
      - pricing
      - retention
EOF
parse_octopus_yml "$TMPDIR4/.octopus-c.yml"
[[ "$OCTOPUS_KNOWLEDGE_ENABLED" == "true" ]] || { echo "FAIL: Format C: KNOWLEDGE_ENABLED expected true"; exit 1; }
[[ "$OCTOPUS_KNOWLEDGE_MODE" == "explicit" ]] || { echo "FAIL: Format C: KNOWLEDGE_MODE expected explicit, got '$OCTOPUS_KNOWLEDGE_MODE'"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_LIST[0]}" == "domain" ]] || { echo "FAIL: Format C: list[0] expected domain"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_LIST[1]}" == "auth" ]] || { echo "FAIL: Format C: list[1] expected auth"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_LIST[2]}" == "pricing" ]] || { echo "FAIL: Format C: list[2] expected pricing"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_LIST[3]}" == "retention" ]] || { echo "FAIL: Format C: list[3] expected retention"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_ROLES[backend-specialist]}" == "domain,auth" ]] || { echo "FAIL: Format C: backend-specialist role expected 'domain,auth', got '${OCTOPUS_KNOWLEDGE_ROLES[backend-specialist]}'"; exit 1; }
[[ "${OCTOPUS_KNOWLEDGE_ROLES[product-manager]}" == "domain,pricing,retention" ]] || { echo "FAIL: Format C: product-manager role expected 'domain,pricing,retention', got '${OCTOPUS_KNOWLEDGE_ROLES[product-manager]}'"; exit 1; }

rm -rf "$TMPDIR4"
echo "PASS: knowledge YAML parsing"

# --- Test: knowledge_dir: parsing ---
echo "Test: knowledge_dir YAML parsing"

TMPDIR5=$(mktemp -d)
OCTOPUS_KNOWLEDGE_DIR="knowledge"
OCTOPUS_KNOWLEDGE_ENABLED="false"
OCTOPUS_KNOWLEDGE_MODE=""
OCTOPUS_KNOWLEDGE_LIST=()

cat > "$TMPDIR5/.octopus-kdir.yml" << 'EOF'
agents:
  - claude
knowledge_dir: docs/ai
knowledge: true
EOF
parse_octopus_yml "$TMPDIR5/.octopus-kdir.yml"
[[ "$OCTOPUS_KNOWLEDGE_DIR" == "docs/ai" ]] || { echo "FAIL: knowledge_dir expected 'docs/ai', got '$OCTOPUS_KNOWLEDGE_DIR'"; exit 1; }
[[ "$OCTOPUS_KNOWLEDGE_ENABLED" == "true" ]] || { echo "FAIL: knowledge should still be enabled"; exit 1; }

# Default is preserved when not set
OCTOPUS_KNOWLEDGE_DIR="knowledge"
cat > "$TMPDIR5/.octopus-kdir-default.yml" << 'EOF'
agents:
  - claude
knowledge: true
EOF
parse_octopus_yml "$TMPDIR5/.octopus-kdir-default.yml"
[[ "$OCTOPUS_KNOWLEDGE_DIR" == "knowledge" ]] || { echo "FAIL: knowledge_dir should default to 'knowledge', got '$OCTOPUS_KNOWLEDGE_DIR'"; exit 1; }

rm -rf "$TMPDIR5"
echo "PASS: knowledge_dir YAML parsing"

rm -rf "$TMPDIR"
echo "PASS: all YAML parsing tests passed"
