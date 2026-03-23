---
name: backend-patterns
description: Backend architecture decision patterns for multi-stack projects (Node.js, .NET, Python)
---

# Backend Architecture Patterns

## When to Use

- Designing a new API endpoint or service
- Choosing between architectural patterns (CQRS, event-driven, layered)
- Structuring a new backend feature or module
- Reviewing backend architecture decisions

## API Design Patterns

### Request/Response Flow

```
Request → Validation → Authentication → Authorization → Handler → Response
```

- Validate input at the boundary (schema validation)
- Authenticate before authorizing
- Keep handlers thin — delegate to services
- Return consistent response envelopes: `{ data, error, metadata }`

### Endpoint Organization

- Group endpoints by domain resource, not by HTTP method
- Use route prefixes for versioning when needed: `/api/v1/students`
- Apply auth at the group level, opt-out for public routes

## Service Layer

- One service per domain aggregate or bounded context
- Services orchestrate between repositories and external integrations
- Services are stateless — no instance-level mutable state
- Handle transactions at the service level

```
Endpoint → Service → Repository → Database
                  → External API
                  → Event Bus
```

## Repository Pattern

- Encapsulate all data access behind a uniform interface
- Standard operations: `findAll`, `findById`, `create`, `update`, `delete`
- Keep business logic out — repositories only handle persistence
- Facilitates testing by allowing mock/stub implementations

## Decision Trees

### When to Use CQRS

Use CQRS (Command Query Responsibility Segregation) when:
- Read and write models differ significantly
- Read-heavy workloads need optimized query models
- Complex domain logic on writes, simple reads

Skip CQRS when:
- Simple CRUD with no complex business logic
- Read and write models are identical
- Small team / early stage — adds unnecessary complexity

### When to Use Events

Use event-driven patterns when:
- Multiple services need to react to the same action
- Actions have side effects in other bounded contexts
- You need audit trails or event sourcing
- Temporal decoupling is valuable (async processing)

Use synchronous calls when:
- The caller needs an immediate response
- The operation is simple and fast
- Only one consumer exists

### When to Use Background Jobs

Use background processing for:
- Email/notification sending
- Report generation
- Data import/export
- Scheduled cleanup tasks
- Webhook delivery with retries

## Cross-Stack Patterns

| Pattern | .NET | Node.js | Python |
|---------|------|---------|--------|
| Validation | FluentValidation | Zod | Pydantic |
| ORM | EF Core | Prisma/Drizzle | SQLAlchemy |
| DI | Built-in | Manual/tsyringe | Manual/inject |
| Testing | xUnit + Testcontainers | Vitest + MSW | pytest + testcontainers |
| Logging | Serilog | Pino/Winston | structlog |

## Anti-Patterns to Avoid

- **Fat controllers/handlers** — move logic to services
- **Anemic domain models** — entities should have behavior, not just data
- **Shared mutable state** — services must be stateless
- **Catch-all error handlers** — handle errors at the appropriate level
- **N+1 queries** — use eager loading or batch queries
- **Hardcoded configuration** — use environment variables
