---
name: branch-create
description: Create a development branch following conventions
cli: octopus.sh branch-create
---

## Instructions

1. If no branch name was provided, ask the user:
   - Type: feat, fix, refactor, docs, test, chore, style, perf, ci
   - Short description (lowercase, hyphens, no spaces)
2. Run: `./octopus/cli/octopus.sh branch-create <type>/<description>`
3. The script will:
   - Validate the branch name format (lowercase, hyphens only)
   - Create the branch locally with `git checkout -b`
4. Confirm branch creation to the user
