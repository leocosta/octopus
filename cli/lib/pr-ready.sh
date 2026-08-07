# pr-ready.sh — Mark a draft PR as ready for review
# Usage: octopus.sh pr-ready [<pr-number>]
#
# The number is optional: with none given, it resolves the PR open for the
# current branch, which is how the command gets used right after pr-open.
# Promotion is idempotent — an already-ready PR is reported and exits 0, so
# re-running it (or chaining it in dev-flow) never breaks a sequence.

PR_NUMBER="${1:-}"

if [[ -z "$PR_NUMBER" ]]; then
  PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null) || PR_NUMBER=""
fi

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: octopus.sh pr-ready [<pr-number>]"
  echo ""
  echo "No PR number given and no open PR found for the current branch."
  exit 1
fi

IS_DRAFT=$(gh pr view "$PR_NUMBER" --json isDraft -q '.isDraft')

if [[ "$IS_DRAFT" != "true" ]]; then
  echo "PR #$PR_NUMBER is already ready for review. Nothing to do."
  exit 0
fi

gh pr ready "$PR_NUMBER"
echo "PR #$PR_NUMBER is now ready for review."
echo "Next: /octopus:pr-review $PR_NUMBER"
