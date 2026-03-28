# pr-open.sh — Open a PR following project conventions
# Usage: octopus.sh pr-open --target <branch> [--body-file <path>]

TARGET=""
BODY_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: octopus.sh pr-open --target <branch> [--body-file <path>]"
  echo ""
  echo "Available remote branches:"
  git branch -r | grep -v HEAD | sed 's/^ */  /'
  exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Validate not on main or release
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" =~ ^release/ ]]; then
  echo "ERROR: Cannot open PR from '$CURRENT_BRANCH'. Switch to a feature branch."
  exit 1
fi

# Push branch to remote
git push -u origin "$CURRENT_BRANCH"

# Generate title from branch name: feat/user-enrollment -> feat: user enrollment
PR_TYPE=$(echo "$CURRENT_BRANCH" | cut -d/ -f1)
PR_DESC=$(echo "$CURRENT_BRANCH" | cut -d/ -f2- | tr '-' ' ')
PR_TITLE="${PR_TYPE}: ${PR_DESC}"

# Generate body
CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TEMPLATE="$CLI_DIR/../pr-body-default.md"

generate_pr_body() {
  local base="$1"

  # Summary from recent commits
  local summary
  summary=$(git log "${base}..HEAD" --oneline | head -5 | sed 's/^[a-f0-9]* /- /')

  # Changes categorized
  local added modified deleted
  added=$(git diff --name-status "${base}..HEAD" | grep '^A' | awk '{print "- `" $2 "`"}')
  modified=$(git diff --name-status "${base}..HEAD" | grep '^M' | awk '{print "- `" $2 "`"}')
  deleted=$(git diff --name-status "${base}..HEAD" | grep '^D' | awk '{print "- `" $2 "`"}')

  cat <<BODY
## Summary

${summary:-N/A}

## Changes

### Added
${added:-N/A}

### Modified
${modified:-N/A}

### Deleted
${deleted:-N/A}

## How to Test
1. Review the diff for correctness
BODY
}

if [[ -n "$BODY_FILE" ]]; then
  if [[ ! -f "$BODY_FILE" ]]; then
    echo "ERROR: Body file not found: $BODY_FILE"
    exit 1
  fi
  PR_BODY=$(cat "$BODY_FILE")
else
  PR_BODY=$(generate_pr_body "$TARGET")
fi

# Create PR
gh pr create --base "$TARGET" --title "$PR_TITLE" --body "$PR_BODY"

# Get PR number
PR_NUMBER=$(gh pr view --json number -q '.number')
echo "OCTOPUS_PR=$PR_NUMBER"
