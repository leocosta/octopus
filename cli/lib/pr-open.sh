# pr-open.sh — Open a PR following project conventions
# Usage: octopus.sh pr-open --target <branch> --body-file <path>
#
# The PR body is written by the agent via /octopus:pr-open (see
# commands/pr-open.md and cli/pr-body-default.md). This script does
# not generate body text; it only pushes the branch and calls gh.

TARGET=""
BODY_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)    TARGET="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: octopus.sh pr-open --target <branch> --body-file <path>"
  echo ""
  echo "Available remote branches:"
  git branch -r | grep -v HEAD | sed 's/^ */  /'
  exit 1
fi

if [[ -z "$BODY_FILE" ]]; then
  echo "ERROR: PR body is required; invoke via /octopus:pr-open command (or pass --body-file <path>)."
  exit 1
fi

if [[ ! -f "$BODY_FILE" ]]; then
  echo "ERROR: Body file not found: $BODY_FILE"
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" =~ ^release/ ]]; then
  echo "ERROR: Cannot open PR from '$CURRENT_BRANCH'. Switch to a feature branch."
  exit 1
fi

git push -u origin "$CURRENT_BRANCH"

PR_TYPE=$(echo "$CURRENT_BRANCH" | cut -d/ -f1)
PR_DESC=$(echo "$CURRENT_BRANCH" | cut -d/ -f2- | tr '-' ' ')
PR_TITLE="${PR_TYPE}: ${PR_DESC}"

gh pr create --base "$TARGET" --title "$PR_TITLE" --body-file "$BODY_FILE"

PR_NUMBER=$(gh pr view --json number -q '.number')
echo "OCTOPUS_PR=$PR_NUMBER"
