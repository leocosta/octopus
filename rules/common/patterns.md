# Design Patterns

## Architecture

- **Feature-based organization** — group code by domain, not by technical layer
- **Composition over inheritance** — prefer combining small behaviors over deep class hierarchies
- **Dependency inversion** — depend on abstractions at boundaries, not concrete implementations
- **Separation of concerns** — keep business logic, data access, and presentation in distinct layers

## API Design

- Use consistent response envelope: `{ data, error, metadata }`
- Return appropriate HTTP status codes — don't abuse 200 for errors
- Version APIs when breaking changes are unavoidable
- Use pagination for list endpoints — never return unbounded collections

## Repository Pattern

- Encapsulate data access behind a uniform interface
- Standard operations: `findAll`, `findById`, `create`, `update`, `delete`
- Keep business logic out of repositories — they only handle persistence
- Facilitates testing by allowing mock implementations

## Service Layer

- Orchestrate business logic between repositories and external services
- One service per domain aggregate or bounded context
- Services should be stateless — no instance-level mutable state
- Handle transactions at the service level

## Error Handling Patterns

- **Result pattern** — return success/failure instead of throwing for expected errors
- **Guard clauses** — validate preconditions at function entry, return/throw early
- **Null Object** — use default implementations instead of null checks
- **Retry with backoff** — for transient failures in external calls

## Event-Driven Patterns

- Use events for cross-boundary communication — avoid tight coupling between features
- Events should be immutable data — include all context needed by consumers
- Handle events idempotently — consumers may receive the same event multiple times
- Keep event handlers focused — one handler per side effect
