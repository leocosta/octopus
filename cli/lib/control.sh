#!/usr/bin/env bash
source "$CLI_DIR/lib/ui.sh"

_check_python_deps() {
  python3 -c "import textual" 2>/dev/null && return 0
  if [[ "${1:-}" == "--install-deps" ]]; then
    pip3 install "textual>=0.80" && return 0
  fi
  ui_error "textual not found. Run: octopus control --install-deps"
  exit 1
}

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: octopus control [--install-deps] [--plan <plan.md>]"
  echo "  --plan <file>   Run pipeline runner against an enriched plan file."
  echo "  (no flag)       Open the interactive TUI agent dashboard."
  exit 0
fi

if [[ "${1:-}" == "--plan" ]]; then
  PLAN_FILE="${2:-}"
  if [[ -z "$PLAN_FILE" ]]; then
    ui_error "Usage: octopus control --plan <plan.md>"
    exit 1
  fi
  PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.pipeline "$PLAN_FILE" "${@:3}"
  exit $?
fi

_check_python_deps "$@"
PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.app "$@"
