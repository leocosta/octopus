---
name: dotnet
description: .NET backend architecture patterns, conventions, and decision trees for ASP.NET Core projects
---

# .NET Backend Patterns

## When to Use

- Implementing or refactoring an ASP.NET Core API
- Designing the architecture of a new .NET service
- Choosing between architectural patterns in the .NET ecosystem
- Reviewing .NET code for quality and adherence to best practices

## Stack Detection

Detect .NET projects by looking for:
- `*.csproj` or `*.sln` files in the project root or subdirectories
- `Program.cs` or `Startup.cs` as entry points
- `appsettings.json` configuration files

## API Design — Minimal APIs

### When to Use Minimal APIs vs Controllers

**Prefer Minimal APIs when:**
- Building microservices or small, focused APIs
- Endpoints are simple CRUD or thin delegation to services
- You want less ceremony and faster startup

**Prefer Controllers when:**
- The project already uses controllers consistently
- Complex action filters, model binding, or content negotiation are required
- Large team with established MVC conventions

### Minimal API Patterns

```csharp
// Group endpoints by domain resource
var group = app.MapGroup("/api/v1/students")
    .RequireAuthorization()
    .WithTags("Students");

group.MapGet("/", GetAllStudents);
group.MapGet("/{id:guid}", GetStudentById);
group.MapPost("/", CreateStudent);
group.MapPut("/{id:guid}", UpdateStudent);
group.MapDelete("/{id:guid}", DeleteStudent);
```

**Key conventions:**
- Group endpoints by domain resource, not by HTTP method
- Apply authorization at the group level, opt-out for public routes
- Use route constraints (`{id:guid}`, `{slug:regex(...)`) for input validation at the routing level
- Keep endpoint handlers thin — delegate to services via MediatR or direct injection
- Return `TypedResults` for better OpenAPI documentation:

```csharp
static async Task<Results<Ok<StudentResponse>, NotFound>> GetStudentById(
    Guid id, IMediator mediator)
{
    var result = await mediator.Send(new GetStudentByIdQuery(id));
    return result is not null
        ? TypedResults.Ok(result)
        : TypedResults.NotFound();
}
```

## Dependency Injection

### Registration Patterns

```csharp
// Use extension methods to organize DI registration by module
public static class StudentModule
{
    public static IServiceCollection AddStudentModule(this IServiceCollection services)
    {
        services.AddScoped<IStudentService, StudentService>();
        services.AddScoped<IStudentRepository, StudentRepository>();
        return services;
    }
}

// In Program.cs
builder.Services.AddStudentModule();
```

**Rules:**
- Register services with the **narrowest lifetime possible**: `Scoped` for request-bound, `Singleton` for stateless/thread-safe, `Transient` only for lightweight stateless factories
- Never inject `Scoped` into `Singleton` — causes captive dependency bugs
- Use `IOptions<T>` / `IOptionsSnapshot<T>` for configuration binding, never read `IConfiguration` directly in services
- Prefer interface-based injection for testability

### Options Pattern

```csharp
public class SmtpSettings
{
    public const string SectionName = "Smtp";
    public string Host { get; init; } = string.Empty;
    public int Port { get; init; } = 587;
    public string Username { get; init; } = string.Empty;
}

// Registration
builder.Services.Configure<SmtpSettings>(
    builder.Configuration.GetSection(SmtpSettings.SectionName));

// Usage — inject IOptions<SmtpSettings> or IOptionsSnapshot<SmtpSettings>
```

## Entity Framework Core

### DbContext Patterns

```csharp
public class AppDbContext : DbContext
{
    public DbSet<Student> Students => Set<Student>();
    public DbSet<Enrollment> Enrollments => Set<Enrollment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Apply all IEntityTypeConfiguration from this assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

**Key rules:**
- Use `IEntityTypeConfiguration<T>` for entity mapping — one file per entity, never configure in `OnModelCreating` directly
- Always use **async** methods: `SaveChangesAsync`, `ToListAsync`, `FirstOrDefaultAsync`
- Use `.AsNoTracking()` for read-only queries (significant performance improvement)
- Add `.AsSplitQuery()` when loading multiple collections to avoid cartesian explosion
- Never expose `IQueryable` outside the repository layer — materialize to `IReadOnlyList<T>` or `T?`
- Use `ExecuteUpdateAsync` / `ExecuteDeleteAsync` for bulk operations (EF Core 7+)

### Migration Discipline

- One migration per logical schema change
- Name migrations descriptively: `Add_Student_Address_Fields`, not `Migration_042`
- Never edit a migration that has been applied to any shared environment
- For data migrations, create a separate migration — don't mix schema and data
- Always test `Down()` path before pushing

### Query Patterns

```csharp
// Good: projection to DTO
var students = await context.Students
    .AsNoTracking()
    .Where(s => s.IsActive)
    .Select(s => new StudentListItem(s.Id, s.Name, s.Email))
    .ToListAsync(cancellationToken);

// Bad: loading full entities for read-only display
var students = await context.Students.ToListAsync();
```

## MediatR / CQRS

### When to Use MediatR

**Use when:**
- Separating command/query responsibilities provides clarity
- Cross-cutting behaviors (logging, validation, caching) need centralized pipeline
- Multiple handlers benefit from decoupled invocation

**Skip when:**
- Simple CRUD with no cross-cutting concerns — direct service injection is simpler
- The overhead of request/handler pairs adds ceremony without benefit

### Pipeline Behaviors

```
Request → ValidationBehavior → LoggingBehavior → Handler → Response
```

```csharp
// Validation pipeline behavior with FluentValidation
public class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;

    public ValidationBehavior(IEnumerable<IValidator<TRequest>> validators)
        => _validators = validators;

    public async Task<TResponse> Handle(TRequest request,
        RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var context = new ValidationContext<TRequest>(request);
        var failures = _validators
            .Select(v => v.Validate(context))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count > 0)
            throw new ValidationException(failures);

        return await next();
    }
}
```

### Command/Query Separation

```csharp
// Command — returns void or a simple result
public record CreateStudentCommand(string Name, string Email) : IRequest<Guid>;

// Query — returns data, never modifies state
public record GetStudentByIdQuery(Guid Id) : IRequest<StudentResponse?>;
```

## FluentValidation

### Validator Patterns

```csharp
public class CreateStudentValidator : AbstractValidator<CreateStudentCommand>
{
    public CreateStudentValidator(IStudentRepository repository)
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Nome é obrigatório")
            .MaximumLength(200).WithMessage("Nome deve ter no máximo 200 caracteres");

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email é obrigatório")
            .EmailAddress().WithMessage("Email inválido")
            .MustAsync(async (email, ct) => !await repository.ExistsByEmailAsync(email, ct))
            .WithMessage("Email já cadastrado");

        RuleFor(x => x.Document)
            .NotEmpty()
            .Must(BeValidCpf).WithMessage("CPF inválido");
    }

    private static bool BeValidCpf(string cpf) => CpfValidator.IsValid(cpf);
}
```

**Rules:**
- One validator per command/request — never validate queries
- Register all validators via assembly scanning: `services.AddValidatorsFromAssembly(...)`
- Use `.WithMessage()` in the project's UI language
- Async validators (database checks) go last — fail fast on simple rules first
- Use `Must` / `MustAsync` for custom business rules

## Mapster (Object Mapping)

### Configuration

```csharp
// Global mapping configuration
public static class MappingConfig
{
    public static void RegisterMappings()
    {
        TypeAdapterConfig<Student, StudentResponse>.NewConfig()
            .Map(dest => dest.FullName, src => $"{src.FirstName} {src.LastName}")
            .Map(dest => dest.Age, src => CalculateAge(src.BirthDate));
    }
}

// Usage — prefer Adapt<T> over Mapper
var response = student.Adapt<StudentResponse>();
var students = entities.Adapt<List<StudentListItem>>();
```

**Rules:**
- Register mappings at startup, never configure inline
- Prefer `Adapt<T>()` extension method over injecting `IMapper`
- For complex mappings, use `TypeAdapterConfig` with `.NewConfig()`
- Never map entities directly to API responses — always create explicit DTOs
- Use `[AdaptIgnore]` sparingly — explicit mapping is self-documenting

## Testing

### xUnit + Moq + FluentAssertions

```csharp
public class StudentServiceTests
{
    private readonly Mock<IStudentRepository> _repository = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();
    private readonly StudentService _sut;

    public StudentServiceTests()
    {
        _sut = new StudentService(_repository.Object, _unitOfWork.Object);
    }

    [Fact]
    public async Task CreateStudent_WithValidData_ShouldReturnId()
    {
        // Arrange
        var command = new CreateStudentCommand("John", "john@test.com");
        _repository.Setup(r => r.ExistsByEmailAsync(command.Email, default))
            .ReturnsAsync(false);

        // Act
        var result = await _sut.CreateAsync(command, CancellationToken.None);

        // Assert
        result.Should().NotBeEmpty();
        _repository.Verify(r => r.AddAsync(It.IsAny<Student>(), default), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(default), Times.Once);
    }

    [Fact]
    public async Task CreateStudent_WithDuplicateEmail_ShouldThrow()
    {
        // Arrange
        var command = new CreateStudentCommand("John", "existing@test.com");
        _repository.Setup(r => r.ExistsByEmailAsync(command.Email, default))
            .ReturnsAsync(true);

        // Act
        var act = () => _sut.CreateAsync(command, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<DomainException>()
            .WithMessage("*email*já cadastrado*");
    }
}
```

### Testing Conventions

- **Naming**: `MethodUnderTest_Scenario_ExpectedBehavior`
- **Structure**: Always Arrange / Act / Assert (AAA)
- Use `_sut` (System Under Test) as variable name for the class being tested
- Use `Mock<T>` for dependencies — verify interactions, not internals
- Use `FluentAssertions` for all assertions — never `Assert.Equal`
- Integration tests use `WebApplicationFactory<Program>` with Testcontainers
- Test happy path first, then edge cases, then error paths

### Integration Test Pattern

```csharp
public class StudentEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public StudentEndpointTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetStudent_ReturnsOk_WhenExists()
    {
        var response = await _client.GetAsync("/api/v1/students/{known-id}");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var student = await response.Content.ReadFromJsonAsync<StudentResponse>();
        student.Should().NotBeNull();
        student!.Name.Should().NotBeNullOrEmpty();
    }
}
```

## Error Handling

### Result Pattern

```csharp
// Domain result pattern — avoid exceptions for expected business failures
public record Result<T>
{
    public T? Value { get; init; }
    public Error? Error { get; init; }
    public bool IsSuccess => Error is null;

    public static Result<T> Success(T value) => new() { Value = value };
    public static Result<T> Failure(Error error) => new() { Error = error };
}

public record Error(string Code, string Message);
```

**Rules:**
- Use exceptions for **unexpected** failures (infrastructure, bugs)
- Use Result pattern for **expected** business failures (validation, not found, conflict)
- Global exception handler for unhandled exceptions → 500 with correlation ID
- Always include correlation ID in error responses for traceability
- Log exceptions with structured logging (Serilog)

## Architecture Decision Tree

```
New .NET backend feature?
│
├─ Simple CRUD, < 3 endpoints?
│  └─ Minimal API + Service + Repository (no MediatR)
│
├─ Medium complexity, cross-cutting concerns?
│  └─ Minimal API + MediatR + FluentValidation pipeline
│
├─ Complex domain, multiple aggregates?
│  └─ DDD layers: Domain → Application (MediatR) → Infrastructure (EF Core) → API
│
└─ Event-driven / async processing?
   └─ MediatR notifications + Background services + Message queue
```

## Anti-Patterns to Avoid

- **Fat endpoints** — move logic to services/handlers
- **Injecting DbContext into endpoints** — use repositories or MediatR
- **Synchronous database calls** — always use async/await
- **Magic strings in configuration** — use Options pattern with typed classes
- **Catching `Exception`** — catch specific exceptions or use Result pattern
- **Returning entities from API** — always map to DTOs
- **Missing CancellationToken** — always propagate `CancellationToken` through async chains
- **Using `.Result` or `.Wait()`** — causes deadlocks; always `await`
