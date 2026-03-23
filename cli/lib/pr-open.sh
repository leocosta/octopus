# pr-open.sh — Open a PR following project conventions
# Usage: octopus.sh pr-open --target <branch>

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: octopus.sh pr-open --target <branch>"
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
PR_BODY="## Summary
-

## Related Issues
Closes #

## How to Test
1.

## Screenshots (if applicable)
"

# Create PR
gh pr create --base "$TARGET" --title "$PR_TITLE" --body "$PR_BODY"

# Get PR number
PR_NUMBER=$(gh pr view --json number -q '.number')
echo "OCTOPUS_PR=$PR_NUMBER"
