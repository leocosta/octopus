# C# Error Handling

## Result Pattern

Use a Result type for operation outcomes. Do not throw exceptions for business logic errors.

```csharp
public sealed record Result<T>
{
    public T? Value { get; }
    public string? Error { get; }
    public bool IsSuccess => Error is null;

    private Result(T value) => Value = value;
    private Result(string error) => Error = error;

    public static Result<T> Success(T value) => new(value);
    public static Result<T> Failure(string error) => new(error);
}
```

Map results to HTTP responses at the endpoint level:

```csharp
return result.IsSuccess
    ? Results.Ok(result.Value)
    : Results.Problem(detail: result.Error, statusCode: 400);
```

## ProblemDetails (RFC 7807)

Return **ProblemDetails** for all HTTP error responses. Never expose stack traces or internal details.

```csharp
builder.Services.AddProblemDetails();
```

## FluentValidation

- Create one validator per command/request using `AbstractValidator<T>`
- Register validators via DI: `services.AddValidatorsFromAssembly(typeof(Program).Assembly)`
- Validate at the endpoint level before processing:

```csharp
var validation = await validator.ValidateAsync(request, ct);
if (!validation.IsValid)
    return Results.ValidationProblem(validation.ToDictionary());
```

## Global Exception Middleware

Catch unhandled exceptions and return a generic ProblemDetails response. Log the full exception server-side.

```csharp
app.UseExceptionHandler(error => error.Run(async context =>
{
    context.Response.StatusCode = 500;
    await Results.Problem(
        title: "Internal Server Error",
        statusCode: 500
    ).ExecuteAsync(context);
}));
```

## Structured Logging with Serilog

- Use **message templates**, not string interpolation:

```csharp
logger.LogInformation("Student {StudentId} created by {UserId}", student.Id, userId);
```

- Log levels: `Error` for failures, `Warning` for handled anomalies, `Information` for business events, `Debug` for diagnostics
- Include **correlation IDs** for request tracing
- Never log sensitive data (passwords, tokens, PII)
