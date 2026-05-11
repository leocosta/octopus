---
name: delegate
description: >
  Delegate a task to an Octopus role and return the result inline with
  attribution. Triggers on @<role>: pattern in user messages or via
  /octopus:delegate @<role> <task>.
---

# Delegate — Inline Task Delegation to Roles

## When This Skill Applies

This skill activates when the user's message matches **either** of:

- `@<role>: <task>` — anywhere in the message
- `/octopus:delegate @<role> <task>` — slash command form

The pattern **requires** the colon (`:`) after the role name.
These do NOT trigger this skill:

- `@src/components/Button.tsx` — file mention (no colon)
- `@backend-developer` — bare mention without colon
- `@role:` with empty task body — ask for the task instead

## Steps

### 1 — Parse

Extract from the message:

- `role` — the identifier between `@` and `:` (e.g. `backend-developer`)
- `task` — everything after `:`, trimmed (e.g. `add POST /invoices endpoint`)

### 2 — Validate role

Check whether the role is available:

- **Claude Code / OpenCode:** look for `.claude/agents/<role>.md` (or
  `.opencode/agents/<role>.md`).
- **Inline harnesses:** the role content is already present in context
  via inline delivery — any named role in context is valid.
  If no named role is found in context, use the same "Role not found" response.

**If role not found:** list the available roles by scanning the agents
directory, then respond:

```
Role "@<role>" not found. Available roles:
- backend-developer
- frontend-developer
(adjust to whatever is installed)

Re-send your message with one of the roles above.
```

**If task is empty:** respond with:

```
What should @<role> do? Re-send with the task after the colon.
Example: @<role>: <your task here>
```

### 3 — Dispatch

Detect the active harness capability:

**Native agents** (if the `Agent` tool appears in your available tools):

```
Agent(
  subagent_type = "<role>",        — filename stem, e.g. "backend-developer"
  description   = "Delegated task: <first 60 chars of task>",
  prompt        = "<full task>"
)
```

**Inline harnesses** (if the `Agent` tool is NOT in your available tools):

The role's persona is already injected in context via inline delivery.
Switch to that persona and respond as that role for this turn only.
Do not explain the switch — just respond as the role.

### 4 — Format output

Wrap the agent's response:

```
» <role> respondeu:

<agent response here>
```

Return this to the user in the current conversation.
