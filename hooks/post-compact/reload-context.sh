#!/usr/bin/env bash
# Re-inject working state after context compaction
# Reads ~/.octopus/state/pre-compact.yml (written by pre-compact/save-state.sh)
# and outputs a brief context reminder to stdout for Claude Code to inject.

state_file="${HOME}/.octopus/state/pre-compact.yml"

# Exit silently if no state file exists
if [[ ! -f "$state_file" ]]; then
  exit 0
fi

branch=$(grep '^branch:' "$state_file" 2>/dev/null | cut -d' ' -f2- | tr -d '\n')
timestamp=$(grep '^timestamp:' "$state_file" 2>/dev/null | cut -d' ' -f2- | tr -d '\n')

dirty=$(awk '/^dirty_files:/{flag=1; next} /^[a-z_]/{flag=0} flag && /^  -/{print}' "$state_file" 2>/dev/null)
staged=$(awk '/^staged_files:/{flag=1; next} /^[a-z_]/{flag=0} flag && /^  -/{print}' "$state_file" 2>/dev/null)

# Exit silently if there is no meaningful state to restore
if [[ -z "$branch" && -z "$dirty" && -z "$staged" ]]; then
  exit 0
fi

echo "## Context Restored After Compaction"
echo ""
[[ -n "$branch" ]] && echo "**Branch:** $branch"
[[ -n "$timestamp" ]] && echo "**State saved at:** $timestamp"
if [[ -n "$dirty" ]]; then
  echo ""
  echo "**Uncommitted changes:**"
  echo "$dirty"
fi
if [[ -n "$staged" ]]; then
  echo ""
  echo "**Staged files:**"
  echo "$staged"
fi

exit 0
