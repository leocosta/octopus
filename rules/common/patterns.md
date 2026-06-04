# Design Patterns

> **Override:** create `patterns.local.md` here to replace these entirely.

## Architecture

- **Feature-based organization** — group by domain, not technical layer
- **Composition over inheritance** — favor small behaviors over deep hierarchies
- **Dependency inversion** — depend on abstractions at boundaries
- **Separation of concerns** — business logic, data access, presentation in distinct layers

## API Design

- Consistent response envelope: `{ data, error, metadata }`
- Correct HTTP status codes — don't abuse 200 for errors
- Version APIs when breaking changes are unavoidable
- Paginate list endpoints — never return unbounded collections

## Repository Pattern

- Encapsulate data access behind a uniform interface
- Standard ops: `findAll`, `findById`, `create`, `update`, `delete`
- No business logic in repositories — persistence only
- Enables testing via mock implementations

## Service Layer

- Orchestrate business logic between repositories and external services
- One service per domain aggregate or bounded context
- Stateless — no instance-level mutable state
- Handle transactions at the service level

## Error Handling Patterns

- **Result pattern** — return success/failure instead of throwing for expected errors (see `exceptions.md` for the custom-exception gate)
- **Guard clauses** — validate preconditions at entry, return/throw early
- **Null Object** — default implementations instead of null checks
- **Retry with backoff** — for transient failures in external calls

## Event-Driven Patterns

- Events for cross-boundary communication — avoid tight coupling
- Events are immutable data — include all context consumers need
- Handle events idempotently — the same event may arrive twice
- One handler per side effect
