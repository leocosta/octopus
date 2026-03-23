# Naming & Style Conventions

## Casing Rules

| Target | Convention | Example |
|--------|-----------|---------|
| Variables, functions, hooks | camelCase | `studentCount`, `formatDate`, `useStudents` |
| Components, types, interfaces | PascalCase | `StudentCard`, `StudentFilters` |
| Constants (module-level) | UPPER_SNAKE_CASE | `MAX_RETRIES`, `API_BASE_URL` |
| Enum members | PascalCase | `Status.Active` |

## File Naming

- Component files: PascalCase matching the export (`StudentCard.tsx`)
- Hook files: camelCase matching the hook (`useStudents.ts`)
- Utility/service files: camelCase (`studentService.ts`, `formatDate.ts`)
- Type files: camelCase (`student.types.ts`) or `index.ts` inside a `types/` directory

## Interfaces and Types

Use `interface` for object shapes and component props. Use `type` for unions, intersections, and mapped types.

```ts
// Props and object shapes -> interface
interface StudentCardProps {
  student: Student;
  onSelect: (id: string) => void;
}

// Unions and computed types -> type
type Status = "active" | "inactive" | "suspended";
type StudentWithClasses = Student & { classes: Class[] };
```

## Strict Typing

- Never use `any`. Use `unknown` when the type is genuinely unknown, then narrow it.
- Avoid type assertions (`as`) unless interfacing with untyped libraries.
- Prefer `satisfies` over `as` for type checking without widening:

```ts
const config = {
  api: "/v1",
  timeout: 5000,
} satisfies AppConfig;
```

## Co-location

Export types alongside the feature that owns them. Shared types live in `src/types/`.

```
features/students/types/index.ts   # Student, StudentFilters
src/types/common.ts                # Pagination, ApiResponse<T>
```
