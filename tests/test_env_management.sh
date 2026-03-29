#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

OCTOPUS_MCP=(notion)

# Test 1: .env doesn't exist — should copy from .env.octopus.example
manage_env
[[ -f "$TMPDIR/.env.octopus" ]] || { echo "FAIL: .env.octopus not created"; exit 1; }
grep -q "NOTION_API_TOKEN" "$TMPDIR/.env.octopus" || { echo "FAIL: .env.octopus missing NOTION_API_TOKEN"; exit 1; }
echo "PASS: .env.octopus created from template"

# Test 2: .env.octopus exists but missing vars from MCP — should warn
echo "GITHUB_TOKEN=abc" > "$TMPDIR/.env.octopus"
output=$(manage_env 2>&1)
echo "$output" | grep -q "NOTION_API_TOKEN" || { echo "FAIL: should warn about missing NOTION_API_TOKEN"; exit 1; }
echo "$output" | grep -q "NOTION_WORKSPACE" || { echo "FAIL: should warn about missing NOTION_WORKSPACE"; exit 1; }
echo "PASS: warns about missing MCP vars"

# Test 3: .env exists but missing vars from .env.octopus.example — should show INFO
echo "NOTION_API_TOKEN=abc" > "$TMPDIR/.env.octopus"
echo "NOTION_WORKSPACE=abc" >> "$TMPDIR/.env.octopus"
output=$(manage_env 2>&1)
echo "$output" | grep -q "INFO.*GITHUB_TOKEN" || { echo "FAIL: should info about missing GITHUB_TOKEN from .env.octopus.example"; exit 1; }
echo "PASS: detects new vars from .env.octopus.example"

rm -rf "$TMPDIR"
echo "PASS: all env management tests passed"
