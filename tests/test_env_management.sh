#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

OCTOPUS_MCP=(notion)

# Test 1: .env doesn't exist — should copy from .env.example
manage_env
[[ -f "$TMPDIR/.env" ]] || { echo "FAIL: .env not created"; exit 1; }
grep -q "NOTION_API_TOKEN" "$TMPDIR/.env" || { echo "FAIL: .env missing NOTION_API_TOKEN"; exit 1; }
echo "PASS: .env created from template"

# Test 2: .env exists but missing vars from MCP — should warn
echo "GITHUB_TOKEN=abc" > "$TMPDIR/.env"
output=$(manage_env 2>&1)
echo "$output" | grep -q "NOTION_API_TOKEN" || { echo "FAIL: should warn about missing NOTION_API_TOKEN"; exit 1; }
echo "$output" | grep -q "NOTION_WORKSPACE" || { echo "FAIL: should warn about missing NOTION_WORKSPACE"; exit 1; }
echo "PASS: warns about missing MCP vars"

# Test 3: .env exists but missing vars from .env.example — should show INFO
echo "NOTION_API_TOKEN=abc" > "$TMPDIR/.env"
echo "NOTION_WORKSPACE=abc" >> "$TMPDIR/.env"
output=$(manage_env 2>&1)
echo "$output" | grep -q "INFO.*GITHUB_TOKEN" || { echo "FAIL: should info about missing GITHUB_TOKEN from .env.example"; exit 1; }
echo "PASS: detects new vars from .env.example"

rm -rf "$TMPDIR"
echo "PASS: all env management tests passed"
