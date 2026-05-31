#!/usr/bin/env bash
# cli/lib/lens.sh — `octopus lens` subcommand (RM-110).
# Dispatched by octopus.sh (which sources this after shifting "lens" off "$@").
# Surfaces the consigliere lens-context the consigliere role frames. Read-only.

CL_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./consigliere-lens.sh
source "$CL_CLI_DIR/consigliere-lens.sh"

case "${1:-}" in
  profile)
    [[ $# -ge 2 ]] || { echo "usage: octopus lens profile <root>" >&2; exit 1; }
    cl_profile "$2"
    ;;
  context)
    [[ $# -ge 2 ]] || { echo "usage: octopus lens context <node>" >&2; exit 1; }
    cl_context "$2"
    ;;
  ""|-h|--help)
    echo "usage: octopus lens <profile <root>|context <node>>" >&2
    [[ "${1:-}" == "" ]] && exit 1 || exit 0
    ;;
  *)
    echo "Unknown lens subcommand: $1" >&2
    echo "usage: octopus lens <profile <root>|context <node>>" >&2; exit 1
    ;;
esac
