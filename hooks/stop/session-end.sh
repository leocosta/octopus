#!/usr/bin/env bash
# Persist session state on stop for recovery

set -euo pipefail

state_dir="${HOME}/.octopus/state"
mkdir -p "$state_dir"

{
  echo "timestamp: $(date -Iseconds)"
  echo "branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
  echo "last_commit: $(git log -1 --format='%h %s' 2>/dev/null || echo 'none')"
  echo "uncommitted_changes: $(git diff --stat 2>/dev/null | tail -1 || echo 'none')"
} > "$state_dir/session-end.yml" 2>/dev/null || true

exit 0
