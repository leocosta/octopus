# C# Naming & Style

## Casing Rules

- **PascalCase** for types, methods, properties, public members, and constants
- **camelCase** for local variables and parameters
- **_camelCase** for private fields

```csharp
public sealed class StudentService
{
    private readonly IStudentRepository _repository;

    public async Task<Student> GetByIdAsync(int studentId)
    {
        var result = await _repository.FindAsync(studentId);
        return result;
    }
}
```

## Naming Prefixes & Suffixes

- Prefix interfaces with `I`: `IStudentRepository`, `ITenantProvider`
- Suffix async methods with `Async`: `GetStudentsAsync`, `SaveChangesAsync`
- Constants use PascalCase: `MaxRetryCount`, `DefaultPageSize`
- Use UPPER_SNAKE_CASE only for environment-level constants: `DATABASE_URL`

## File Organization

- One class, record, or interface per file
- Filename must match the type name: `StudentService.cs` contains `StudentService`
- Use **file-scoped namespaces** everywhere:

```csharp
namespace MyApp.Features.Students;

public sealed class Student { }
```

## Language Preferences

- Target **.NET 8+** with **C# 12+**
- Enable nullable reference types: `<Nullable>enable</Nullable>`
- Prefer **sealed** classes unless inheritance is explicitly needed
- Use **primary constructors** for dependency injection
- Use **records** for DTOs, commands, queries, and value objects:

```csharp
public record CreateStudentRequest(string Name, string Email);
public record StudentResponse(int Id, string Name, string Email);
```
