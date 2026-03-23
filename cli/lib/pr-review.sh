# pr-review.sh — Self-review a PR and assign reviewers
# Usage: octopus.sh pr-review <pr-number>

PR_NUMBER="${1:-}"

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: octopus.sh pr-review <pr-number>"
  exit 1
fi

echo "=== PR #$PR_NUMBER Diff ==="
gh pr diff "$PR_NUMBER"

echo ""
echo "=== Self-Review Complete ==="
echo "Review the diff above for: correctness, design, readability, edge cases, security, tests."

# Read reviewers from .octopus.yml if available
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_ROOT="$(cd "$OCTOPUS_DIR/.." && pwd)"

if [[ -f "$PROJECT_ROOT/.octopus.yml" ]]; then
  # Parse reviewers section, stopping at next top-level key
  REVIEWERS=$(awk '/^reviewers:/{found=1; next} found && /^[a-z]/{exit} found && /^ *-/{gsub(/^ *- */, ""); print}' "$PROJECT_ROOT/.octopus.yml")
  if [[ -n "$REVIEWERS" ]]; then
    REVIEWER_LIST=$(echo "$REVIEWERS" | tr '\n' ',' | sed 's/,$//')
    echo "Assigning reviewers: $REVIEWER_LIST"
    gh pr edit "$PR_NUMBER" --add-reviewer "$REVIEWER_LIST"
  fi
fi
