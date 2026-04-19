# Workflow

PR and branch automation commands powered by GitHub CLI (`gh`).

## Available workflow commands

| Command | What it does |
|---|---|
| `/octopus:branch-create` | Create a branch following naming conventions |
| `/octopus:pr-open` | Push branch and create a PR |
| `/octopus:pr-review` | Request review from configured reviewers |
| `/octopus:pr-comments` | Handle PR comment feedback |
| `/octopus:pr-merge` | Merge a PR |
| `/octopus:codereview` | Run a code review workflow |
| `/octopus:dev-flow` | Full development flow |
| `/octopus:doc-rfc` | Bootstrap an RFC document from template |
| `/octopus:doc-spec` | Bootstrap a spec document from template |
| `/octopus:doc-adr` | Bootstrap an ADR document from template |
| `/octopus:release` | Create a release, sync version docs, and tag it |
| `/octopus:update` | Update Octopus to a newer version |

## How it works

1. Enable in `.octopus.yml`:
   ```yaml
   workflow: true
   reviewers:
     - github-username
   ```
2. Ensure `gh` is installed and authenticated: `gh auth login`
3. Run `octopus setup`
4. **Claude Code**: commands become individual slash command files
5. **Other agents**: commands are listed with CLI invocation instructions
