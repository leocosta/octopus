#!/usr/bin/env bash
# Track MCP server failures and suggest recovery

set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

if [[ "$tool_name" == mcp__* ]]; then
  # Extract server name from tool_name (format: mcp__server__tool)
  server_name=$(echo "$tool_name" | cut -d'_' -f3)
  echo "WARNING: MCP server '$server_name' call failed. Check server health:" >&2
  echo "  - Verify the server is running" >&2
  echo "  - Check environment variables for the server" >&2
  echo "  - Review .claude/settings.json mcpServers configuration" >&2
fi

exit 0
