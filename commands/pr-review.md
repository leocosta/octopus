---
name: pr-review
description: Self-review a PR and assign human reviewers
cli: octopus.sh pr-review
---

## Instructions

1. Run: `./octopus/cli/octopus.sh pr-review <pr-number>`
2. The script will output the PR diff
3. Perform a self-review of the diff, checking for:
   - **Correctness** — does the code do what it claims?
   - **Design** — does it fit the existing architecture?
   - **Readability** — can someone unfamiliar understand it?
   - **Edge cases** — missing error handling, null checks
   - **Security** — injection, auth bypass, data exposure
   - **Tests** — are the right things tested?
4. Report any issues found to the user with specific suggestions
5. If issues are found, help the user fix them, then commit and push
6. Assign human reviewers (configured in .octopus.yml)
7. Inform the user: "PR is now in review. Invoke /octopus:pr-comments <number> when there is feedback."
