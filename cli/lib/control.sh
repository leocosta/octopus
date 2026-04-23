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
  echo "Usage: octopus control [--install-deps]"
  echo "  Open the TUI agent dashboard."
  exit 0
fi

_check_python_deps "$@"
PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.app "$@"
