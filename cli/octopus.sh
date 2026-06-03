#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="$CLI_DIR/lib/commands.default"

# Is "$1" a registered workflow command? The registry — not the mere existence
# of cli/lib/<name>.sh — defines what is dispatchable, so helper libs never run.
is_command() {
  awk -F'|' -v name="$1" '/^[^#]/ && NF>=2 && $1==name {found=1} END{exit !found}' "$REGISTRY"
}

print_usage() {
  echo "Usage: octopus.sh <command> [args]"
  echo ""
  echo "Commands:"
  awk -F'|' '/^[^#]/ && NF>=2 { printf "  %-14s %s\n", $1, $2 }' "$REGISTRY"
  echo ""
  echo "Global commands (via bin/octopus shim): install, update, doctor, version."
}

# octopus help <cmd>  /  octopus <cmd> --help — one-line summary from the registry.
print_command_help() {
  local name="$1" desc
  desc="$(awk -F'|' -v n="$name" '/^[^#]/ && NF>=2 && $1==n {print $2}' "$REGISTRY")"
  if [[ -z "$desc" ]]; then
    echo "Unknown command: $name" >&2
    echo "Run 'octopus.sh help' for the list of commands." >&2
    return 1
  fi
  echo "octopus $name — $desc"
  echo ""
  echo "Run 'octopus $name' to use the command."
}

# Emit a shell completion script listing the global + workflow commands.
print_completions() {
  local shell="${1:-bash}" workflow globals all c
  workflow="$(awk -F'|' '/^[^#]/ && NF>=2 { printf "%s ", $1 }' "$REGISTRY")"
  globals="install update doctor version help list completions"
  all="$globals $workflow"
  case "$shell" in
    bash)
      cat <<EOF
# octopus bash completion — source <(octopus completions bash)
_octopus_complete() {
  if [[ \$COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( \$(compgen -W "$all" -- "\${COMP_WORDS[1]}") )
  fi
}
complete -F _octopus_complete octopus
EOF
      ;;
    zsh)
      cat <<EOF
#compdef octopus
# octopus zsh completion — source <(octopus completions zsh)
_octopus() { compadd $all }
compdef _octopus octopus
EOF
      ;;
    fish)
      for c in $all; do
        echo "complete -c octopus -n __fish_use_subcommand -a $c"
      done
      ;;
    *)
      echo "Unknown shell: $shell (use bash, zsh, or fish)" >&2
      return 1
      ;;
  esac
}

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  -h | --help)
    print_usage; exit 0 ;;
  help)
    if [[ -n "${1:-}" ]]; then print_command_help "$1"; exit $?; fi
    print_usage; exit 0 ;;
  list)
    awk -F'|' '/^[^#]/ && NF>=2 { print $1 }' "$REGISTRY"; exit 0 ;;
  completions)
    print_completions "${1:-bash}"; exit $? ;;
  "")
    print_usage >&2; exit 1 ;;
esac

# octopus <cmd> --help / -h → that command's one-line summary.
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && is_command "$COMMAND"; then
  print_command_help "$COMMAND"
  exit 0
fi

if ! is_command "$COMMAND"; then
  echo "Unknown command: $COMMAND" >&2
  echo "Run 'octopus.sh help' for the list of commands." >&2
  exit 1
fi

source "$CLI_DIR/lib/${COMMAND}.sh"
