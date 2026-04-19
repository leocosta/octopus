#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

OCTOPUS_MCP=(notion github)
OCTOPUS_AGENTS=(claude)
declare -A OCTOPUS_AGENT_OUTPUT=()

# Create .claude dir with base settings (deliver_mcp expects settings.json to exist)
mkdir -p "$TMPDIR/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR/.claude/settings.json"

load_manifest "claude"
deliver_mcp "claude"

# Verify notion + github servers were injected
python3 -c "
import json, sys
with open('$TMPDIR/.claude/settings.json') as f:
    data = json.load(f)
servers = data.get('mcpServers', {})
assert 'notion' in servers, f'notion not in mcpServers: {list(servers.keys())}'
assert 'github' in servers, f'github not in mcpServers: {list(servers.keys())}'
assert servers['notion']['type'] == 'http', 'notion type should be http'
assert servers['notion']['url'] == 'https://mcp.notion.com/mcp', 'notion url wrong'
assert servers['github']['command'] == 'npx', 'github command wrong'
print('PASS: MCP injection verified')
" || { echo "FAIL: MCP injection verification failed"; exit 1; }

# Test Codex MCP injection (if codex CLI is available). Uses a sibling
# directory that mirrors the real repo layout so `load_manifest codex`
# finds agents/codex/manifest.yml while the test-only MCP config lives in
# its local mcp/ subdir.
if command -v codex &>/dev/null; then
  codex mcp remove octopus-test-stdio 2>/dev/null || true

  FAKE_OCTOPUS="$TMPDIR/octopus-fake"
  mkdir -p "$FAKE_OCTOPUS/mcp" "$FAKE_OCTOPUS/agents"
  cp -r "$SCRIPT_DIR/agents/codex" "$FAKE_OCTOPUS/agents/codex"

  cat > "$FAKE_OCTOPUS/mcp/octopus-test-stdio.json" << 'EOF'
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
  OCTOPUS_DIR="$FAKE_OCTOPUS"

  load_manifest "codex"
  deliver_mcp "codex"

  codex mcp list 2>/dev/null | grep -q "octopus-test-stdio" || { echo "FAIL: Codex MCP injection failed"; exit 1; }
  echo "PASS: Codex MCP injection verified"

  codex mcp remove octopus-test-stdio 2>/dev/null || true
fi

rm -rf "$TMPDIR"
echo "PASS: all MCP tests passed"
