# Spec: GitHub Action scaffolding

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Status** | Implemented |
| **Roadmap** | RM-016 |
| **Research** | [boris-cherny-tips](../research/2026-03-30-boris-cherny-tips.md) (GitHub Action section) |

## Problem

Boris's CI pattern runs Claude Code on every pull request for automated review and comment. The workflow boilerplate (checkout, CLI install, secret wiring, output posting) is the same across repos but tedious to write manually, and easy to get subtly wrong (missing permissions, timeout, token scopes).

## Design

New manifest flag `githubAction: true` (camelCase for consistency with `effortLevel` / `permissionMode` / `outputStyle`). When enabled and Claude is in `agents:`, `deliver_github_action` copies `templates/github-actions/claude.yml` into `.github/workflows/claude.yml`.

The template:
- Triggers on `pull_request` (opened/synchronize/reopened)
- Requests `contents:read`, `pull-requests:write`, `issues:write`
- Installs Claude Code from the official installer
- Runs `claude code review --pr <number>` and posts the output via `gh pr comment`
- Uses `ANTHROPIC_API_KEY` from repo secrets

**Idempotent:** if `.github/workflows/claude.yml` already exists, Octopus leaves it alone. Users can customize freely without fear of being overwritten on the next `octopus setup`.

**Secrets contract:** users must add `ANTHROPIC_API_KEY` to the repo's secrets before the workflow runs. The scaffold does not assume any particular API key source — only references the secret name.

## Out of scope

- GitLab CI / CircleCI / other provider scaffolds.
- Multiple workflow variants (nightly review, issue triage) — ship one; users can fork.
- Managing the `ANTHROPIC_API_KEY` secret via Octopus (requires GitHub API write access the CLI does not have).
