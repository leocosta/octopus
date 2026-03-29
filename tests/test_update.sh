#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/../cli/octopus.sh"

# Test 1: unknown version rejected
echo "Test 1: Unknown version rejected"
output=$(bash "$CLI" update --version v99.99.99 2>&1 || true)
echo "$output" | grep -qi "error\|not found" || { echo "FAIL: should error on unknown version"; exit 1; }
echo "PASS: Unknown version rejected"

# Test 2: CLI help lists 'update' command
echo "Test 2: CLI routes 'update' command"
_help=$(bash "$CLI" 2>&1 || true)
echo "$_help" | grep -q "update" || { echo "FAIL: 'update' not in CLI help"; exit 1; }
echo "PASS: CLI routes 'update' command"

echo "PASS: all update tests passed"
