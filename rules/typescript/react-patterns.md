# React Patterns

## Components

- Functional components only. No class components.
- Always type props with an `interface` named `{Component}Props`.
- Prefer composition over configuration. Small, focused components.

```tsx
interface StudentCardProps {
  student: Student;
  variant?: "compact" | "full";
}

export function StudentCard({ student, variant = "full" }: StudentCardProps) {
  return <Card>...</Card>;
}
```

## Feature-Based Architecture

Organize by domain, not by technical layer:

```
src/
  features/
    students/
      components/     # StudentCard, StudentList
      hooks/          # useStudents, useCreateStudent
      services/       # studentService.ts
      types/          # Student, StudentFilters
      pages/          # StudentsPage, StudentDetailPage
  components/         # Shared UI (DataTable, PageHeader)
  hooks/              # Shared hooks (useDebounce, useLocalStorage)
  lib/                # Utilities, API client, cn()
```

## Custom Hooks

- One hook per file, named `use{Feature}{Action}.ts`.
- Hooks encapsulate data fetching, mutations, derived state, side effects.
- Components render. Hooks handle logic.

```tsx
// features/students/hooks/useDeleteStudent.ts
export function useDeleteStudent() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: studentService.delete,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["students"] }),
  });
}
```

## Composition Patterns

- Use `children` for layout wrappers and slots.
- Use render props or compound components for complex UI (tables, forms).
- Lift shared state to the nearest common ancestor, not higher.

## Routing (React Router 6)

- Central route config with lazy-loaded page components.
- `<Outlet />` for nested layouts.
- Page components live in `features/{domain}/pages/`.

```tsx
const Students = React.lazy(() => import("@/features/students/pages/StudentsPage"));
```

## Error Handling

- Wrap route segments with React Error Boundaries.
- Handle async errors in hooks (React Query `onError`, try/catch).
- Show errors via toast notifications, not inline alerts.
