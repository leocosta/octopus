#!/usr/bin/env bash
# Load previous session context on startup
# Outputs context information for the agent to consume

set -euo pipefail

state_dir="${HOME}/.octopus/state"
state_file="$state_dir/pre-compact.yml"

# If previous state exists, output summary
if [[ -f "$state_file" ]]; then
  echo "Previous session state found:" >&2
  cat "$state_file" >&2
  echo "" >&2
fi

# Announce available knowledge modules
# Read knowledge_dir from .octopus.yml if configured, else default to "knowledge"
knowledge_dir="knowledge"
if [[ -f ".octopus.yml" ]]; then
  _kd=$(grep -E '^knowledge_dir:[[:space:]]+' .octopus.yml 2>/dev/null | awk '{print $2}' | head -1)
  [[ -n "$_kd" ]] && knowledge_dir="$_kd"
fi
if [[ -d "$knowledge_dir" && -f "$knowledge_dir/INDEX.md" ]]; then
  echo "Knowledge modules available:" >&2
  grep -E '^\|.*Active' "$knowledge_dir/INDEX.md" 2>/dev/null | \
    awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print "  - " $2}' >&2
  echo "Consult ${knowledge_dir}/INDEX.md for domain routing." >&2
fi

# Detect package manager for the project
if [[ -f "package-lock.json" ]]; then
  echo "Package manager: npm" >&2
elif [[ -f "yarn.lock" ]]; then
  echo "Package manager: yarn" >&2
elif [[ -f "pnpm-lock.yaml" ]]; then
  echo "Package manager: pnpm" >&2
elif [[ -f "bun.lockb" ]]; then
  echo "Package manager: bun" >&2
elif [[ -f "pyproject.toml" ]]; then
  echo "Package manager: python (pyproject.toml)" >&2
elif [[ -f "*.sln" ]] 2>/dev/null || [[ -f "*.csproj" ]] 2>/dev/null; then
  echo "Package manager: dotnet" >&2
fi

exit 0
