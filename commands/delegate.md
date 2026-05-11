---
name: delegate
description: Delegate a task to an Octopus role — returns result inline with attribution (» role respondeu:).
---

---
description: Delegate a task to an Octopus role — returns result inline with attribution (» role respondeu:).
agent: code
---

# /octopus:delegate

## Purpose

This command dispatches a task to a named Octopus role and returns
the result inline with attribution, without leaving the current
harness session.

## Usage

```
/octopus:delegate @<role> <task description>
```

**Examples:**

```
/octopus:delegate @backend-developer add POST /invoices endpoint to the API
/octopus:delegate @frontend-developer create a Button component with loading state
```

## Instructions

Invoke the `delegate` skill (`skills/delegate/SKILL.md`). The skill owns the full workflow — do not reinterpret it here.

Parse the arguments before invoking:
- `role` = the identifier following `@` (everything up to the first space after `@`)
- `task` = everything after the role identifier, trimmed
