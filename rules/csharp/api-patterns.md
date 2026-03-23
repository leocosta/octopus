# C# API Patterns

## Minimal APIs Only

Use `app.MapGroup()` with extension methods. **No controllers.**

```csharp
public static class StudentEndpoints
{
    public static RouteGroupBuilder MapStudentEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/students")
            .WithTags("Students")
            .RequireAuthorization();

        group.MapGet("/", GetStudents.Handle);
        group.MapGet("/{id:int}", GetStudentById.Handle);
        group.MapPost("/", CreateStudent.Handle);
        group.MapPut("/{id:int}", UpdateStudent.Handle);
        group.MapDelete("/{id:int}", DeleteStudent.Handle);

        return group;
    }
}
```

## Endpoint Handlers

Each endpoint is a static class with a `Handle` method. Keep handlers thin.

```csharp
public static class CreateStudent
{
    public record Request(string Name, string Email);
    public record Response(int Id, string Name);

    public static async Task<IResult> Handle(
        Request request,
        IValidator<Request> validator,
        AppDbContext db,
        CancellationToken ct)
    {
        var validation = await validator.ValidateAsync(request, ct);
        if (!validation.IsValid)
            return Results.ValidationProblem(validation.ToDictionary());

        var student = new Student(request.Name, request.Email);
        db.Students.Add(student);
        await db.SaveChangesAsync(ct);

        return Results.Created($"/students/{student.Id}", new Response(student.Id, student.Name));
    }
}
```

## Request & Response DTOs

- Use **records** for all request/response types
- Define DTOs inside the endpoint class or in the feature folder
- Never expose entities directly in API responses

## Authentication & Authorization

- Use **JWT Bearer** authentication
- Apply `.RequireAuthorization()` on endpoint groups
- Use policy-based authorization for role/permission checks:

```csharp
group.MapDelete("/{id:int}", DeleteStudent.Handle)
    .RequireAuthorization("AdminOnly");
```
