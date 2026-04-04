---
name: pr-merge
description: Merge an approved PR
cli: octopus.sh pr-merge
---

---
description: Merge an approved PR
agent: code
---

## Instructions

1. Run: `octopus pr-merge <pr-number>` (the legacy shim remains for now).
2. The script will:
   - Check if the PR is approved and all checks pass
   - If not approved: report the current status and stop
   - If approved: merge with squash and delete the branch
3. Report the result to the user
