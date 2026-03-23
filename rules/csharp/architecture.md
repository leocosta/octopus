# C# Architecture

## Vertical Slice

Organize code by **feature**, not by technical layer. Each feature folder is self-contained.

```
Features/
  Students/
    Endpoints.cs          # Minimal API endpoint definitions
    CreateStudent.cs      # Command + Handler
    GetStudents.cs        # Query + Handler
    StudentValidator.cs   # FluentValidation
    Student.cs            # Entity
  Classes/
    Endpoints.cs
    CreateClass.cs
    ...
Infrastructure/           # Shared: DbContext, middleware, auth, DI registration
```

## Feature Folder Rules

- Each feature folder contains its own endpoints, commands/queries, validators, and entities
- A feature should not reference another feature's internal types directly
- Shared concerns (DbContext, middleware, auth, configuration) live in `Infrastructure/`

## Dependency Injection

- Register feature services with extension methods per feature:

```csharp
public static class StudentModule
{
    public static IServiceCollection AddStudentFeature(this IServiceCollection services)
    {
        services.AddScoped<IStudentRepository, StudentRepository>();
        return services;
    }

    public static IEndpointRouteBuilder MapStudentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/students").RequireAuthorization();
        group.MapGet("/", GetStudents.Handle);
        group.MapPost("/", CreateStudent.Handle);
        return app;
    }
}
```

- Wire everything in `Program.cs`:

```csharp
builder.Services.AddStudentFeature();
// ...
app.MapStudentEndpoints();
```

## Key Packages

- `Microsoft.EntityFrameworkCore` + `Npgsql.EntityFrameworkCore.PostgreSQL`
- `FluentValidation.DependencyInjectionExtensions`
- `Serilog.AspNetCore`
- `Microsoft.AspNetCore.Authentication.JwtBearer`
- `Testcontainers.PostgreSql` (test projects)
