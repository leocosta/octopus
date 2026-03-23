#!/usr/bin/env bash
# Session end lifecycle marker — logs session completion

set -euo pipefail

state_dir="${HOME}/.octopus/state"
mkdir -p "$state_dir"

echo "$(date -Iseconds) session-end" >> "$state_dir/lifecycle.log" 2>/dev/null || true

exit 0
