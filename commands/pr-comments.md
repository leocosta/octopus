---
name: pr-comments
description: Address PR review comments
cli: octopus.sh pr-comments
---

## Instructions

1. Run: `./octopus/cli/octopus.sh pr-comments <pr-number>`
2. The script will output pending review comments with context (file, line, comment text)
3. For each comment:
   a. Understand what the reviewer is asking for
   b. Implement the requested change
   c. Commit with a descriptive message
   d. Push the changes
   e. Reply on the comment thread indicating it was addressed
4. After addressing all comments, inform the user of the changes made
5. Suggest invoking /octopus:pr-merge when the PR is approved
