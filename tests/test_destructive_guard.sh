#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$SCRIPT_DIR/hooks/pre-tool-use/destructive-guard.sh"

echo "Test 1: guard script exists and is executable"
[[ -x "$GUARD" ]] || { echo "FAIL: $GUARD missing or not executable"; exit 1; }
echo "PASS: script present"
