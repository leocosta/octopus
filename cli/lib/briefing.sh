#!/usr/bin/env bash
# cli/lib/briefing.sh — `octopus briefing` subcommand (RM-109).
# Dispatched by octopus.sh (which sources this after shifting "briefing" off "$@").
# Proactive cadence summary over a knowledge root.

KB_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./knowledge-briefing.sh
source "$KB_CLI_DIR/knowledge-briefing.sh"

KB_ROOT=""; KB_MODE="daily"; KB_SINCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)   KB_ROOT="${2:-}"; shift 2 ;;
    --daily)  KB_MODE="daily"; shift ;;
    --weekly) KB_MODE="weekly"; shift ;;
    --since)  KB_SINCE="${2:-}"; shift 2 ;;
    -h|--help)
      echo "usage: octopus briefing [--root <id>] [--daily|--weekly] [--since <window>]" >&2; exit 0 ;;
    *)
      echo "Unknown briefing option: $1" >&2
      echo "usage: octopus briefing [--root <id>] [--daily|--weekly] [--since <window>]" >&2; exit 1 ;;
  esac
done

kb_run
