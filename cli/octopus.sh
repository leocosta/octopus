#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMAND="${1:-}"
shift 2>/dev/null || true

if [[ -z "$COMMAND" ]]; then
  echo "Usage: octopus.sh <command> [args]"
  echo ""
  echo "Commands:"
  echo "  branch-create  Create a development branch"
  echo "  pr-open        Open a PR following conventions"
  echo "  pr-review      Self-review a PR and assign reviewers"
  echo "  pr-comments    Address PR review comments"
  echo "  pr-merge       Merge an approved PR"
  echo "  release        Create a versioned release with tag and CHANGELOG"
  exit 1
fi

LIB_SCRIPT="$CLI_DIR/lib/${COMMAND}.sh"

if [[ ! -f "$LIB_SCRIPT" ]]; then
  echo "Unknown command: $COMMAND"
  echo "Run 'octopus.sh' without arguments for usage."
  exit 1
fi

source "$LIB_SCRIPT"
