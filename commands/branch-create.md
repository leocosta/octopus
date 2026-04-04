---
name: branch-create
description: Create a development branch following conventions
cli: octopus.sh branch-create
---

---
description: Create a development branch following Octopus conventions
agent: code
---

## Instructions

1. If no branch name was provided:
   - Infer a branch name from recent context (current task, last user message, open files, git status)
   - Choose the appropriate type: feat, fix, refactor, docs, test, chore, style, perf, ci
   - Propose: "Suggested branch: `<type>/<description>` — proceed? (or tell me a different name)"
   - Wait for confirmation or correction before creating
2. Run: `octopus branch-create <type>/<description>` (legacy shim `./octopus/cli/octopus.sh ...` forwards to the global CLI).
3. The script will:
   - Validate the branch name format (lowercase, hyphens only)
   - Create the branch locally with `git checkout -b`
4. Confirm branch creation to the user
