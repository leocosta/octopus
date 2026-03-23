# C# Data Access

## EF Core + PostgreSQL

- Use `Npgsql.EntityFrameworkCore.PostgreSQL` as the provider
- Apply **snake_case** naming convention for all tables and columns

```csharp
public class StudentConfiguration : IEntityTypeConfiguration<Student>
{
    public void Configure(EntityTypeBuilder<Student> builder)
    {
        builder.ToTable("students");
        builder.Property(s => s.FirstName).HasColumnName("first_name");
        builder.Property(s => s.TenantId).HasColumnName("tenant_id");
    }
}
```

## Entity Configuration

- Place entity configurations in the feature folder or a shared `Persistence/` folder
- Apply configurations via `OnModelCreating`:

```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}
```

## Migrations

- Use EF Core migrations for all schema changes
- Never modify the database manually
- Name migrations descriptively: `AddStudentEmail`, `CreateClassesTable`

## Loading Strategy

- **No lazy loading.** Ever.
- Use explicit `.Include()` for related data:

```csharp
var student = await db.Students
    .Include(s => s.Enrollments)
    .FirstOrDefaultAsync(s => s.Id == id, ct);
```

## Multi-Tenancy

- All tenant-scoped entities must have a `TenantId` property
- Apply tenant filtering via **EF Core global query filters**:

```csharp
modelBuilder.Entity<Student>()
    .HasQueryFilter(s => s.TenantId == _tenantProvider.TenantId);
```

- Use **interceptors** to auto-set `TenantId` on insert
- Never bypass tenant filtering without explicit justification and code review
