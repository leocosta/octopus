#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="$CLI_DIR/lib/commands.default"

# Is "$1" a registered workflow command? The registry — not the mere existence
# of cli/lib/<name>.sh — defines what is dispatchable, so helper libs never run.
is_command() {
  awk -F'|' -v name="$1" '/^[^#]/ && NF>=2 && $1==name {found=1} END{exit !found}' "$REGISTRY"
}

print_usage() {
  echo "Usage: octopus.sh <command> [args]"
  echo ""
  echo "Commands:"
  awk -F'|' '/^[^#]/ && NF>=2 { printf "  %-14s %s\n", $1, $2 }' "$REGISTRY"
  echo ""
  echo "Global commands (via bin/octopus shim): install, update, doctor."
}

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  -h | --help | help)
    print_usage
    exit 0
    ;;
  "")
    print_usage >&2
    exit 1
    ;;
esac

if ! is_command "$COMMAND"; then
  echo "Unknown command: $COMMAND" >&2
  echo "Run 'octopus.sh help' for the list of commands." >&2
  exit 1
fi

source "$CLI_DIR/lib/${COMMAND}.sh"
