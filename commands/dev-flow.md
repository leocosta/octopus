---
name: dev-flow
description: Full development workflow orchestrator
---

---
description: Full development workflow orchestrator
agent: code
---

## Instructions

This is the full development workflow. Execute steps in order with pauses
for human interaction.

### Step 1: Create Branch
- Ask the user for branch type and name
- Run /octopus:branch-create with the provided name
- After branch is created, tell the user:
  "Branch created. Develop the feature. When ready, say 'continue' or invoke /octopus:pr-open"

### PAUSE — Wait for the user to develop the feature

### Step 2: Open PR
- When the user says "continue" or invokes this step:
- Run /octopus:pr-open (will ask for target branch)
- Capture the PR number from the output

### Step 3: Self-Review
- Run /octopus:pr-review with the captured PR number
- After review and reviewer assignment, tell the user:
  "PR is open and in review. Invoke /octopus:pr-comments <number> when there is feedback."

### PAUSE — Wait for human review

### Step 4: Address Comments (repeatable)
- Run /octopus:pr-comments with the PR number
- Can be invoked multiple times as new feedback arrives

### Step 5: Merge
- Run /octopus:pr-merge with the PR number
- Only proceeds if PR is approved

### PAUSE — Wait for merge to complete

### Step 6: Release (optional)
- After successful merge, ask the user:
  "Branch merged successfully. Do you want to create a release? Say 'release' or 'skip'."
- If the user says "release" or equivalent:
  - Run /octopus:release
- If the user says "skip" or equivalent:
  - Proceed to Step 7

### Step 7: Cleanup
- Remove the git worktree if one exists for this branch:
  `git worktree remove .worktrees/<branch-name>`
- Delete the local branch:
  `git branch -d <branch-name>`
- Delete the remote branch:
  `git push origin --delete <branch-name>`
- Confirm: "All clean. Worktree and branch removed."
