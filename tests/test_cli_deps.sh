#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

# --- Test 1: warns when gh is missing ---
echo "Test 1: Missing gh warning"

TMPDIR=$(mktemp -d)
ORIG_PATH="$PATH"
export PATH="$TMPDIR"  # override PATH completely to hide gh

OCTOPUS_WORKFLOW=true
output=$(NO_COLOR=1 validate_cli_deps 2>&1) || true
export PATH="$ORIG_PATH"
echo "$output" | grep -qi "gh.*not found" || { echo "FAIL: should warn about missing gh"; exit 1; }

echo "PASS: warns about missing gh"

# --- Test 2: no warning when workflow is false ---
echo "Test 2: No warning when workflow disabled"

OCTOPUS_WORKFLOW=false
output=$(NO_COLOR=1 validate_cli_deps 2>&1) || true
echo "$output" | grep -qi "gh" && { echo "FAIL: should not warn when workflow is false"; exit 1; } || true

echo "PASS: no warning when workflow disabled"

rm -rf "$TMPDIR"
echo "PASS: all cli deps tests passed"
