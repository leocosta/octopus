---
name: pr-open
description: Open a PR following project conventions
cli: octopus.sh pr-open
---

## Instructions

1. Ask the user which target branch to open the PR against
   - Default: `main`
   - If `release/*` branches exist, list them as options
2. Run: `./octopus/cli/octopus.sh pr-open --target <branch>`
3. The script will:
   - Push the current branch to remote
   - Create the PR with title and body following conventions
   - Output `OCTOPUS_PR=<number>`
4. Capture the PR number from the output
5. Report the PR URL to the user
6. Automatically proceed to invoke /octopus:pr-review with the captured PR number
