#!/usr/bin/env bash
# cli/lib/synthesize.sh — `octopus synthesize` subcommand (RM-108).
# Dispatched by octopus.sh (which sources this after shifting "synthesize" off "$@").
# Surfaces connections that cross nodes of a knowledge root.

KS_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./knowledge-synthesize.sh
source "$KS_CLI_DIR/knowledge-synthesize.sh"

KS_ROOT=""; KS_NODE=""; KS_FIX=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) KS_ROOT="${2:-}"; shift 2 ;;
    --node) KS_NODE="${2:-}"; shift 2 ;;
    --fix)  KS_FIX=1; shift ;;
    -h|--help)
      echo "usage: octopus synthesize [--root <id>] [--node <path>] [--fix]" >&2; exit 0 ;;
    *)
      echo "Unknown synthesize option: $1" >&2
      echo "usage: octopus synthesize [--root <id>] [--node <path>] [--fix]" >&2; exit 1 ;;
  esac
done

ks_run
