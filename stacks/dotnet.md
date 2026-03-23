# .NET Conventions

## Runtime & Language

- Target **.NET 8+** with **C# 12+**
- Enable nullable reference types (`<Nullable>enable</Nullable>`)
- Use file-scoped namespaces (`namespace X;`)
- Prefer **sealed** classes and records unless inheritance is explicitly needed
- Use **primary constructors** for dependency injection
- Use **records** for DTOs, commands, queries, and value objects

## Naming & Style

- PascalCase for types, methods, properties, and public members
- camelCase for local variables and parameters
- `_camelCase` for private fields
- `I` prefix for interfaces (`IStudentRepository`)
- Async methods suffixed with `Async` (`GetStudentsAsync`)
- Constants in PascalCase (`MaxRetryCount`) or UPPER_SNAKE_CASE for environment-level constants
- One class/record per file, filename matches type name

## Architecture — Vertical Slice

Organize code by feature, not by technical layer:

```
Features/
  Students/
    Endpoints.cs          # Minimal API endpoint definitions
    CreateStudent.cs      # Command + Handler
    GetStudents.cs        # Query + Handler
    StudentValidator.cs   # FluentValidation
    Student.cs            # Entity
  Classes/
    ...
Infrastructure/           # Shared: DbContext, middleware, auth, DI registration
```

- Each feature folder is self-contained with its endpoints, commands/queries, validators, and entities
- Shared infrastructure (DbContext, middleware, auth) lives outside `Features/`

## API Style — Minimal APIs

- Use `app.MapGroup()` with extension methods to organize endpoints — **no controllers**
- Group related endpoints by feature:

```csharp
public static class StudentEndpoints
{
    public static RouteGroupBuilder MapStudentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/students").RequireAuthorization();
        group.MapGet("/", GetStudents.Handle);
        group.MapPost("/", CreateStudent.Handle);
        return group;
    }
}
```

## Data Access — EF Core + PostgreSQL

- Use **snake_case** naming convention for tables and columns
- Configure via `HasTableName("students")` and `HasColumnName("first_name")` in entity configurations
- Place entity configurations in the feature folder or a shared `Persistence/` folder
- Use migrations for schema changes — never modify the database manually
- Avoid lazy loading; use explicit `.Include()` for related data

## Multi-Tenancy

- Apply tenant filtering via **EF Core interceptors** or global query filters
- All tenant-scoped entities must have a `TenantId` property
- Never bypass tenant filtering without explicit justification

## Validation — FluentValidation

- Create one validator class per command/request: `AbstractValidator<T>`
- Register validators via DI (`.AddValidatorsFromAssembly()`)
- Validate at the endpoint level before processing

## Authentication & Authorization

- Use **JWT Bearer** authentication
- Apply `.RequireAuthorization()` on endpoint groups
- Use policy-based authorization for role/permission checks

## Error Handling

- Use the **Result pattern** for operation outcomes (avoid throwing exceptions for business logic errors)
- Return **ProblemDetails** for HTTP error responses (RFC 7807)
- Let unhandled exceptions be caught by global exception middleware
- Never expose stack traces or internal details in API responses

## Logging

- Use **Serilog** with structured logging
- Log with message templates, not string interpolation:

```csharp
logger.LogInformation("Student {StudentId} created by {UserId}", student.Id, userId);
```

- Log levels: `Error` for failures, `Warning` for handled anomalies, `Information` for business events, `Debug` for diagnostics
- Never log sensitive data (passwords, tokens, PII)
- Include correlation IDs for request tracing

## Testing

- Use **xUnit** as the test framework
- Use **Testcontainers** for integration tests with a real PostgreSQL instance
- Do not mock the database — integration tests must hit a real database
- Name tests with the pattern: `MethodName_Scenario_ExpectedResult`
- Use `FluentAssertions` for readable assertions

## Dependencies

Key packages:
- `Microsoft.EntityFrameworkCore` + `Npgsql.EntityFrameworkCore.PostgreSQL`
- `FluentValidation.DependencyInjectionExtensions`
- `Serilog.AspNetCore`
- `Microsoft.AspNetCore.Authentication.JwtBearer`
- `Testcontainers.PostgreSql` (test projects)
