# pr-merge.sh — Merge an approved PR
# Usage: octopus.sh pr-merge <pr-number>

PR_NUMBER="${1:-}"

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: octopus.sh pr-merge <pr-number>"
  exit 1
fi

# Check approval status
REVIEW_DECISION=$(gh pr view "$PR_NUMBER" --json reviewDecision -q '.reviewDecision')
CHECKS_STATUS=$(gh pr checks "$PR_NUMBER" 2>&1) || true

if [[ "$REVIEW_DECISION" != "APPROVED" ]]; then
  echo "PR #$PR_NUMBER is not approved. Current status: ${REVIEW_DECISION:-PENDING}"
  echo ""
  echo "Review status:"
  gh pr view "$PR_NUMBER" --json reviews -q '.reviews[] | "\(.author.login): \(.state)"'
  exit 1
fi

echo "PR #$PR_NUMBER is approved. Merging with squash..."
gh pr merge "$PR_NUMBER" --squash --delete-branch

echo "PR #$PR_NUMBER merged successfully."
