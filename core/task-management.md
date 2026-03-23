# Task Management

## Notion as Source of Truth

All tasks, bugs, and features are tracked in Notion. The Notion board is the single source of truth for what needs to be done, what's in progress, and what's completed.

## Task Lifecycle

1. **Backlog** — new tasks land here after triage
2. **To Do** — prioritized and ready to be picked up
3. **In Progress** — actively being worked on (assign yourself)
4. **In Review** — PR created, awaiting code review
5. **Done** — merged to main and verified

## Working with Tasks

- Always pick tasks from **To Do** — don't skip prioritization
- Move the task to **In Progress** before starting work
- One task at a time — finish or park before starting another
- Link the Notion task in the PR description
- Move to **Done** only after the PR is merged

## Branch and Commit Linking

- Use the task ID from Notion in the branch name when available: `feat/TASK-123-student-enrollment`
- Reference the task in commit messages or PR descriptions: `Closes TASK-123`

## Bug Reports

When filing bugs in Notion, include:
- Steps to reproduce
- Expected vs. actual behavior
- Environment (browser, OS, API version)
- Screenshots or logs when applicable

## AI Agent Integration

When an MCP server for Notion is configured, AI agents can:
- Query the backlog for task details and context
- Look up acceptance criteria before implementing
- Check related tasks for dependencies

Agents should **read** from Notion for context but **not create or modify** tasks without explicit user instruction.
