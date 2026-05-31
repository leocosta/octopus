#!/usr/bin/env bash
# cli/lib/hygiene.sh — `octopus hygiene` subcommand (RM-107).
# Dispatched by octopus.sh (which sources this after shifting "hygiene" off "$@").
# Audits a knowledge root for staleness / broken links / orphans / archive drift.

KH_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./knowledge-hygiene.sh
source "$KH_CLI_DIR/knowledge-hygiene.sh"

KH_ROOT=""; KH_GAPS=0; KH_FIX=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)  KH_ROOT="${2:-}"; shift 2 ;;
    --gaps)  KH_GAPS=1; shift ;;
    --fix)   KH_FIX=1; shift ;;
    -h|--help)
      echo "usage: octopus hygiene [--root <id>] [--gaps] [--fix]" >&2; exit 0 ;;
    *)
      echo "Unknown hygiene option: $1" >&2
      echo "usage: octopus hygiene [--root <id>] [--gaps] [--fix]" >&2; exit 1 ;;
  esac
done

kh_run
