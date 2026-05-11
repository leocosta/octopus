---
name: delegate
description: Delegate a task to an Octopus role — returns result inline with attribution (» role respondeu:).
---

---
description: Delegate a task to an Octopus role — returns result inline with attribution (» role respondeu:).
agent: code
---

# /octopus:delegate

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

Invoke the `delegate` skill (`skills/delegate/SKILL.md`) with:

- `role` = the identifier following `@` (everything up to the first space after `@`)
- `task` = everything after the role identifier, trimmed

The skill handles:
- Role validation (lists available roles if not found)
- Dispatch mode detection (native Agent tool vs inline persona)
- Output formatting with `» <role> respondeu:` attribution
