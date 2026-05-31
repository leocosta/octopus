#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMAND="${1:-}"
shift 2>/dev/null || true

if [[ -z "$COMMAND" ]]; then
  echo "Usage: octopus.sh <command> [args]"
  echo ""
  echo "Commands:"
  echo "  setup          Configure Octopus in the current repository (--reconfigure to edit)"
  echo "  uninstall      Remove Octopus artifacts from the current repository"
  echo "  branch-create  Create a development branch"
  echo "  dev-flow       Run the guided development workflow"
  echo "  pr-open        Open a PR following conventions"
  echo "  pr-review      Self-review a PR and assign reviewers"
  echo "  pr-comments    Address PR review comments"
  echo "  pr-merge       Merge an approved PR"
  echo "  release        Create a versioned release with tag and CHANGELOG"
  echo "  control        Open the TUI agent dashboard"
  echo "  ask            Dispatch a task to a specific agent with live streaming output"
  echo "  run            Run a feature end-to-end: requirement → spec → plan → agents → PR"
  echo "  kr             Query the knowledge-root registry (list/meta/nodes/links/archive)"
  echo "  hygiene        Audit a knowledge root (staleness/orphans/links/archive)"
  echo "  synthesize     Surface cross-node connections in a knowledge root"
  echo "  briefing       Proactive cadence summary over a knowledge root"
  echo ""
  echo "Global commands (via bin/octopus shim): install, update, doctor."
  exit 1
fi

LIB_SCRIPT="$CLI_DIR/lib/${COMMAND}.sh"

if [[ ! -f "$LIB_SCRIPT" ]]; then
  echo "Unknown command: $COMMAND"
  echo "Run 'octopus.sh' without arguments for usage."
  exit 1
fi

source "$LIB_SCRIPT"
