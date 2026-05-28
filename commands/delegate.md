---
name: delegate
description: (Octopus) Delegate one task or a multi-step pipeline to Octopus roles — sequential, parallel, with confirmation gates between steps.
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
