# branch-create.sh — Create a development branch
# Usage: octopus.sh branch-create <type/name>

BRANCH_NAME="${1:-}"

if [[ -z "$BRANCH_NAME" ]]; then
  echo "Usage: octopus.sh branch-create <type/name>"
  echo "Example: octopus.sh branch-create feat/user-enrollment"
  exit 1
fi

# Validate format: type/description (lowercase, hyphens)
if [[ ! "$BRANCH_NAME" =~ ^(feat|fix|refactor|docs|test|chore|style|perf|ci)/[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERROR: Invalid branch name '$BRANCH_NAME'"
  echo "Format: <type>/<description> (lowercase, hyphens only)"
  echo "Types: feat, fix, refactor, docs, test, chore, style, perf, ci"
  exit 1
fi

git checkout -b "$BRANCH_NAME"
echo "Branch '$BRANCH_NAME' created."
