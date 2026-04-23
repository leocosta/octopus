#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../cli" && pwd)"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test: octopus control --help exits 0"
bash "$CLI_DIR/octopus.sh" control --help \
  || { echo "FAIL: control --help returned non-zero"; exit 1; }
echo "PASS"

echo "Test: octopus control --help mentions dashboard"
bash "$CLI_DIR/octopus.sh" control --help | grep -q "dashboard" \
  || { echo "FAIL: --help missing 'dashboard'"; exit 1; }
echo "PASS"

echo "Test: app.tcss exists and defines accent color"
grep -q "7B2FBE" "$REPO_DIR/cli/control/app.tcss" \
  || { echo "FAIL: accent color missing from app.tcss"; exit 1; }
grep -q "1a1a2e" "$REPO_DIR/cli/control/app.tcss" \
  || { echo "FAIL: background color missing from app.tcss"; exit 1; }
echo "PASS"
