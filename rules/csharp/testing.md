# C# Testing

## Stack

- **xUnit** as the test framework
- **Testcontainers** for integration tests with real PostgreSQL
- **FluentAssertions** for readable assertions

## Test Naming

Follow the pattern: `MethodName_Scenario_ExpectedResult`

```csharp
public class CreateStudentTests
{
    [Fact]
    public async Task Handle_ValidRequest_ReturnsCreatedStudent() { }

    [Fact]
    public async Task Handle_DuplicateEmail_ReturnsConflict() { }

    [Fact]
    public async Task Handle_MissingName_ReturnsValidationError() { }
}
```

## Integration Tests with Testcontainers

Do not mock the database. Integration tests must hit a real PostgreSQL instance.

```csharp
public class DatabaseFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        // Apply migrations
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;
        await using var db = new AppDbContext(options);
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();
}

[CollectionDefinition("Database")]
public class DatabaseCollection : ICollectionFixture<DatabaseFixture> { }
```

## Assertions

Use FluentAssertions for all test assertions:

```csharp
result.Should().NotBeNull();
result.Name.Should().Be("Alice");
students.Should().HaveCount(3).And.OnlyContain(s => s.IsActive);
```

## Rules

- One test class per feature/handler
- Share the database container across tests in a collection
- Clean up test data between tests or use transactions
- Test both happy paths and error cases
