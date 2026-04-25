#!/usr/bin/env bash
set -euo pipefail
source "$CLI_DIR/lib/ui.sh"

if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: octopus ask <role> "<task>" [--skill <skill>] [--model <model>] [--dry-run]
       octopus ask <role> --reply "<text>" [--model <model>]

Dispatch a task to a specific agent and stream its output live in the terminal.
Use --reply to continue an existing session without opening octopus control.
Ctrl+C during streaming offers [k]ill, [d]etach (keep running in background), or [c]ancel.

Examples:
  octopus ask tech-writer "write ADR for JWT authentication"
  octopus ask backend-specialist "run security audit on src/auth/"
  octopus ask tech-writer "write ADR" --skill octopus:doc-adr
  octopus ask tech-writer "write ADR" --dry-run
  octopus ask tech-writer --reply "yes, proceed with the plan"
EOF
  exit 0
fi

ROLE="${1:-}"

if [[ -z "$ROLE" ]]; then
  ui_error "Role is required. Usage: octopus ask <role> \"<task>\""
  exit 1
fi

PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.ask "$ROLE" "${@:2}"
