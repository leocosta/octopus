# C# Coding Style

> **Override:** create `coding-style.local.md` here to replace these entirely.

## Braces — Always Required

Every control flow statement **must** use braces, even for single-line bodies:

```csharp
// correct
if (condition)
{
    DoSomething();
}

// wrong — never omit braces
if (condition)
    DoSomething();
```

Applies to: `if`, `else`, `for`, `foreach`, `while`, `do`, `using (non-declaration)`.

## Brace Style

Use **Allman style** (opening brace on its own line):

```csharp
if (isValid)
{
    Process();
}
else
{
    Reject();
}
```

## Type Inference

Use `var` when the type is obvious from the right-hand side:

```csharp
var user = new User();                  // obvious — use var
var students = await db.Students.ToListAsync(); // obvious — use var
IEnumerable<User> result = GetItems();  // not obvious — declare type
```

## Null Handling

- Prefer null-conditional operators when chaining: `user?.Address?.City`
- Use null-coalescing for defaults: `name ?? "Unknown"`
- Avoid explicit `!= null` checks when the null-conditional operator suffices

## String Formatting

Prefer **interpolation** over concatenation:

```csharp
var message = $"Student {student.Name} enrolled in {course.Title}";
```

Use **raw string literals** for multi-line or embedded quotes (C# 11+):

```csharp
var json = """
    {
        "name": "Alice"
    }
    """;
```

## Expression Bodies

Use expression bodies only when the entire body fits on one line and reads clearly:

```csharp
public string FullName => $"{FirstName} {LastName}";
public bool IsActive => Status == StudentStatus.Active;
```

Do not use expression bodies for methods with meaningful logic.

## .editorconfig Reference

These rules map to the following `.editorconfig` settings:

```ini
[*.cs]
csharp_prefer_braces = always:error
dotnet_diagnostic.IDE0011.severity = error
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = false:suggestion
```
