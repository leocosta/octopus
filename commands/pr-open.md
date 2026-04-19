---
name: pr-open
description: Open a PR following project conventions
cli: octopus.sh pr-open
---

---
description: Open a PR following Octopus conventions
agent: code
---

Open a pull request using the Octopus CLI.

## Arguments

Use `$ARGUMENTS` to determine the target branch and optional body file.

- Target branch: `$1` (default: `main`)
- Optional: `--body-file <path>` for a custom PR body

## Instructions

1. Run `git branch -r | grep -v HEAD` to list available remote branches.
2. If no target branch was provided as `$1`, ask the user which branch to target (default: `main`).
3. Run the Octopus PR open command:
   ```
   octopus pr-open --target <branch>
   ```
4. If the user provided `--body-file <path>` in `$ARGUMENTS`, pass it through:
   ```
   octopus pr-open --target <branch> --body-file <path>
   ```
5. Parse the PR number from the output (format: `OCTOPUS_PR=<number>`).
6. Run `gh pr view <number> --json url,body -q '"URL: \(.url)\n\n## PR Body\n\(.body)"'` to get the PR URL and body.
7. Display the full PR body so the user can see exactly what was submitted.
8. Report the PR URL to the user and suggest running `/octopus:pr-review <number>` next.

The default template at `cli/pr-body-default.md` is used automatically when no `--body-file` is specified.
