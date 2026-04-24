#!/usr/bin/env bash
set -euo pipefail
source "$CLI_DIR/lib/ui.sh"

if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: octopus ask <role> "<task>" [--skill <skill>] [--model <model>] [--dry-run]

Dispatch a task to a specific agent and stream its output live in the terminal.
Ctrl+C during streaming offers [k]ill, [d]etach (keep running in background), or [c]ancel.

Examples:
  octopus ask tech-writer "write ADR for JWT authentication"
  octopus ask backend-specialist "run security audit on src/auth/"
  octopus ask tech-writer "write ADR" --skill octopus:doc-adr
  octopus ask tech-writer "write ADR" --dry-run
EOF
  exit 0
fi

ROLE="${1:-}"
TASK="${2:-}"

if [[ -z "$ROLE" ]]; then
  ui_error "Role is required. Usage: octopus ask <role> \"<task>\""
  exit 1
fi

if [[ -z "$TASK" ]]; then
  ui_error "Task is required. Usage: octopus ask <role> \"<task>\""
  exit 1
fi

PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.ask "$ROLE" "$TASK" "${@:3}"
