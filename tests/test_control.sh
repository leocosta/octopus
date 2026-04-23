#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../cli" && pwd)"

echo "Test: octopus control --help exits 0"
bash "$CLI_DIR/octopus.sh" control --help \
  || { echo "FAIL: control --help returned non-zero"; exit 1; }
echo "PASS"
