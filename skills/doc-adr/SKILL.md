---
name: doc-adr
description: Create and manage Architecture Decision Records (ADRs) to document significant technical decisions
---

# Architecture Decision Records

## When to Use

- Making a significant technology choice (framework, database, library)
- Choosing between architectural patterns (monolith vs microservices, REST vs GraphQL)
- Changing an existing architectural decision
- When someone asks "why did we choose X?"

## ADR Format (MADR)

Use the Markdown Any Decision Record format. Save in `docs/adrs/`:

```markdown
# NNN - Title of Decision

## Status

Accepted | Superseded by [NNN](NNN-title.md) | Deprecated

## Date

YYYY-MM-DD

## Context

What is the issue that we're seeing that is motivating this decision or change?
Describe the forces at play (technical, business, team, constraints).
2-5 sentences.

## Decision

What is the change that we're proposing and/or doing?
State the decision in 1-3 clear sentences.

## Alternatives Considered

### Alternative A — [Name]
- **Pros:** ...
- **Cons:** ...

### Alternative B — [Name]
- **Pros:** ...
- **Cons:** ...

## Consequences

### Positive
- ...

### Negative
- ...

### Risks
- ...
```

## Workflow

### Creating a New ADR

1. Check existing ADRs: `ls docs/adrs/`
2. Determine next number: increment from highest existing
3. Create file: `docs/adrs/NNN-short-kebab-title.md`
4. Fill in all sections — no section should be empty
5. Set status to `Accepted`
6. Update the index if one exists

### File Naming Convention

```
docs/adrs/
├── 001-use-postgresql-for-primary-database.md
├── 002-adopt-vertical-slice-architecture.md
├── 003-choose-react-query-for-state-management.md
└── README.md  (optional index)
```

- Three-digit zero-padded number
- Kebab-case title
- Short but descriptive (under 60 characters)

### Superseding a Decision

When a previous decision is reversed or replaced:

1. Create a new ADR with the new decision
2. Update the old ADR's status: `Superseded by [NNN](NNN-title.md)`
3. Reference the old ADR in the new one's Context section

## Decision Categories

| Category | Examples |
|----------|----------|
| Technology | Database, framework, language, cloud provider |
| Architecture | Monolith vs microservices, sync vs async, caching strategy |
| API Design | REST vs GraphQL, versioning strategy, auth mechanism |
| Data | Schema design, migration strategy, backup policy |
| Infrastructure | Hosting, CI/CD, monitoring, deployment strategy |
| Security | Auth provider, encryption, secret management |
| Testing | Framework choice, coverage requirements, test strategy |
| Process | Branching strategy, code review policy, release process |

## Guidelines

- Write ADRs when the decision is made, not after — capture the reasoning while it's fresh
- Include rejected alternatives — future readers need to know what was considered
- Keep them concise — an ADR is not a design document
- ADRs are immutable once accepted — create new ones to change decisions
- Not every decision needs an ADR — only significant ones that affect architecture
