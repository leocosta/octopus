# dev-flow.sh — Guided development workflow orchestration
# Usage:
#   octopus.sh dev-flow start <type/name>
#   octopus.sh dev-flow continue --target <branch> [--body-file <path>]
#   octopus.sh dev-flow review <pr-number>
#   octopus.sh dev-flow comments <pr-number>
#   octopus.sh dev-flow merge <pr-number>
#   octopus.sh dev-flow release [args...]

ACTION="${1:-}"
shift 2>/dev/null || true

usage() {
  cat <<'EOF'
Usage:
  octopus.sh dev-flow start <type/name>
  octopus.sh dev-flow continue --target <branch> [--body-file <path>]
  octopus.sh dev-flow review <pr-number>
  octopus.sh dev-flow comments <pr-number>
  octopus.sh dev-flow merge <pr-number>
  octopus.sh dev-flow release [args...]

Workflow:
  start     Create the branch for the feature
  continue  Push the current branch and open the PR
  review    Run self-review on the PR
  comments  Address review comments on the PR
  merge     Merge the approved PR
  release   Run the release workflow
EOF
}

if [[ -z "$ACTION" ]]; then
  usage
  exit 1
fi

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$ACTION" in
  start)
    if [[ $# -lt 1 ]]; then
      echo "ERROR: Missing branch name."
      usage
      exit 1
    fi

    source "$CLI_DIR/branch-create.sh" "$1"
    echo "Branch created. Develop the feature. When ready, run:"
    echo "  ./cli/octopus.sh dev-flow continue --target main"
    ;;

  continue)
    source "$CLI_DIR/pr-open.sh" "$@"
    echo "PR is open. Next steps:"
    echo "  ./cli/octopus.sh dev-flow review <pr-number>"
    echo "  ./cli/octopus.sh dev-flow comments <pr-number>  # when feedback arrives"
    ;;

  review)
    if [[ $# -lt 1 ]]; then
      echo "ERROR: Missing PR number."
      usage
      exit 1
    fi

    source "$CLI_DIR/pr-review.sh" "$1"
    echo "PR reviewed. Wait for human feedback, then run:"
    echo "  ./cli/octopus.sh dev-flow comments $1"
    ;;

  comments)
    if [[ $# -lt 1 ]]; then
      echo "ERROR: Missing PR number."
      usage
      exit 1
    fi

    source "$CLI_DIR/pr-comments.sh" "$1"
    ;;

  merge)
    if [[ $# -lt 1 ]]; then
      echo "ERROR: Missing PR number."
      usage
      exit 1
    fi

    source "$CLI_DIR/pr-merge.sh" "$1"
    echo "PR merged. If you need a release, run:"
    echo "  ./cli/octopus.sh dev-flow release"
    ;;

  release)
    source "$CLI_DIR/release.sh" "$@"
    ;;

  *)
    echo "ERROR: Unknown dev-flow action '$ACTION'."
    usage
    exit 1
    ;;
esac
