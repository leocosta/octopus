#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

OCTOPUS_MCP=(notion github)
OCTOPUS_AGENTS=(claude)

# Create .claude dir with base settings
mkdir -p "$TMPDIR/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR/.claude/settings.json"

inject_mcp_servers

# Verify notion server was injected
python3 -c "
import json, sys
with open('$TMPDIR/.claude/settings.json') as f:
    data = json.load(f)
servers = data.get('mcpServers', {})
assert 'notion' in servers, f'notion not in mcpServers: {servers.keys()}'
assert 'github' in servers, f'github not in mcpServers: {servers.keys()}'
assert servers['notion']['type'] == 'http', 'notion type should be http'
assert servers['notion']['url'] == 'https://mcp.notion.com/mcp', 'notion url wrong'
assert servers['github']['command'] == 'npx', 'github command wrong'
print('PASS: MCP injection tests passed')
" || { echo "FAIL: MCP injection verification failed"; exit 1; }

# Test Codex MCP injection (if codex CLI is available)
if command -v codex &>/dev/null; then
  # Remove any existing test server
  codex mcp remove octopus-test-stdio 2>/dev/null || true

  # Create a stdio-type MCP config (no OAuth, won't hang)
  mkdir -p "$TMPDIR/mcp"
  cat > "$TMPDIR/mcp/octopus-test-stdio.json" << 'EOF'
{
  "octopus-test-stdio": {
    "command": "npx",
    "args": ["@test/mcp-server"],
    "env": {
      "TEST_TOKEN": "${TEST_TOKEN}"
    }
  }
}
EOF

  OCTOPUS_MCP=(octopus-test-stdio)
  OCTOPUS_AGENTS=(codex)
  OCTOPUS_DIR="$TMPDIR"

  inject_mcp_servers

  # Verify codex has the server
  codex mcp list 2>/dev/null | grep -q "octopus-test-stdio" || { echo "FAIL: Codex MCP injection failed"; exit 1; }
  echo "PASS: Codex MCP injection verified"

  # Cleanup
  codex mcp remove octopus-test-stdio 2>/dev/null || true
fi

rm -rf "$TMPDIR"
