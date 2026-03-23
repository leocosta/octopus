#!/usr/bin/env bash
# Save working state before context compaction
# Preserves git status and recent context for session recovery

set -euo pipefail

state_dir="${HOME}/.octopus/state"
mkdir -p "$state_dir"

# Save current branch and uncommitted changes summary
{
  echo "timestamp: $(date -Iseconds)"
  echo "branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
  echo "dirty_files:"
  git diff --name-only 2>/dev/null | head -20 | sed 's/^/  - /' || true
  echo "staged_files:"
  git diff --cached --name-only 2>/dev/null | head -20 | sed 's/^/  - /' || true
} > "$state_dir/pre-compact.yml" 2>/dev/null || true

exit 0
