#!/usr/bin/env bash
# cli/lib/kr.sh — `octopus kr` subcommand (RM-106).
# Dispatched by octopus.sh (which sources this after shifting "kr" off "$@").
# Line-oriented read interface over the knowledge-root registry.

KR_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./knowledge-root.sh
source "$KR_CLI_DIR/knowledge-root.sh"

kr_sub="${1:-}"; shift 2>/dev/null || true

case "$kr_sub" in
  list)
    kr_load | cut -d'|' -f1
    ;;
  meta)
    [[ $# -ge 2 ]] || { echo "usage: octopus kr meta <id> <field>" >&2; exit 1; }
    kr_field "$1" "$2"
    ;;
  nodes)
    [[ $# -ge 1 ]] || { echo "usage: octopus kr nodes <id>" >&2; exit 1; }
    kr_nodes "$1"
    ;;
  archive)
    [[ $# -ge 1 ]] || { echo "usage: octopus kr archive <id>" >&2; exit 1; }
    kr_archive "$1"
    ;;
  links)
    [[ $# -ge 2 ]] || { echo "usage: octopus kr links <id> <node>" >&2; exit 1; }
    kr_links "$1" "$2"
    ;;
  ""|-h|--help)
    echo "usage: octopus kr <list|meta|nodes|links|archive>" >&2
    [[ "$kr_sub" == "" ]] && exit 1 || exit 0
    ;;
  *)
    echo "Unknown kr subcommand: $kr_sub" >&2
    echo "usage: octopus kr <list|meta|nodes|links|archive>" >&2
    exit 1
    ;;
esac
