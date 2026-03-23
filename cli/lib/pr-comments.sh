# pr-comments.sh — List PR review comments for the agent to address
# Usage: octopus.sh pr-comments <pr-number>

PR_NUMBER="${1:-}"

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: octopus.sh pr-comments <pr-number>"
  exit 1
fi

echo "=== PR #$PR_NUMBER Review Comments ==="
gh pr view "$PR_NUMBER" --comments

echo ""
echo "=== Review Threads ==="
gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" \
  --jq '.[] | "File: \(.path):\(.line // .original_line)\nComment: \(.body)\n---"' 2>/dev/null || true

echo ""
echo "Address each comment above, commit, push, and reply on the thread."
