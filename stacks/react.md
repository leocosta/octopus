# React Conventions

## Runtime & Language

- **React 18+** with **TypeScript** in strict mode
- **Vite** as the build tool
- Use functional components only — no class components

## Naming & Style

- camelCase for variables, functions, hooks
- PascalCase for components, types, and interfaces
- `use` prefix for hooks (`useStudents`, `useAuth`)
- Component files in PascalCase (`StudentCard.tsx`), hook files in camelCase (`useStudents.ts`)
- Use `interface` for component props and object shapes
- Avoid `any` — use `unknown` when the type is truly unknown
- Co-locate type exports with their feature (`features/{domain}/types/`)

## Architecture — Feature-Based

Organize code by domain feature, not by technical role:

```
src/
  features/
    students/
      components/       # Feature-specific components
      hooks/            # Custom hooks (1 hook per file)
      services/         # API call functions
      types/            # TypeScript interfaces and types
      pages/            # Route-level page components
    classes/
      ...
  components/           # Shared/generic components
  hooks/                # Shared custom hooks
  lib/                  # Utilities, API client setup
```

## Routing — React Router 6

- Define routes in a central config, with page components lazy-loaded:

```tsx
const Students = React.lazy(() => import("@/features/students/pages/StudentsPage"));
```

- Use `<Outlet />` for nested layouts
- Place page components in `features/{domain}/pages/`

## Data Fetching — React Query 5 (TanStack Query)

- Create **one custom hook per domain query/mutation**:

```tsx
// features/students/hooks/useStudents.ts
export function useStudents(filters?: StudentFilters) {
  return useQuery({
    queryKey: ["students", filters],
    queryFn: () => studentService.getAll(filters),
  });
}
```

- Query key convention: `[domain, ...params]` (e.g., `["students", id]`, `["classes", { page }]`)
- Use `useMutation` with `onSuccess` invalidation for writes
- Never call API functions directly in components — always go through hooks

## UI Components — shadcn/ui + Radix UI + Tailwind CSS 3

- Use **shadcn/ui** components as the base component library
- Use the `cn()` utility for conditional class merging:

```tsx
import { cn } from "@/lib/utils";
<div className={cn("base-class", isActive && "active-class")} />
```

- Follow shadcn/ui patterns for composition (e.g., `Card`, `CardHeader`, `CardContent`)
- Use Tailwind CSS for styling — avoid inline styles and CSS modules

## Forms — react-hook-form + Zod

- Define form schemas with **Zod**, infer TypeScript types from them:

```tsx
const studentSchema = z.object({
  name: z.string().min(1, "Required"),
  email: z.string().email(),
});

type StudentFormData = z.infer<typeof studentSchema>;
```

- Use `useForm` with `zodResolver`:

```tsx
const form = useForm<StudentFormData>({
  resolver: zodResolver(studentSchema),
});
```

- Integrate with shadcn/ui `<Form>` components

## Custom Hooks Pattern

- Extract business logic and state management into custom hooks
- **One hook per file**, named `use{Feature}{Action}.ts`
- Hooks should encapsulate: data fetching, mutations, derived state, and side effects
- Components should focus on rendering, delegating logic to hooks

## API Layer

- Use a centralized **Axios instance** with interceptors for:
  - Auth token injection (Bearer header)
  - Tenant header injection
  - Error response handling (401 redirect, toast notifications)
- Place API service functions in `features/{domain}/services/`
- Service functions return typed data, not raw Axios responses

## Error Handling

- Use React Error Boundaries for rendering errors
- Handle async errors in hooks (React Query `onError`, try/catch in mutations)
- Show user-friendly error messages via toast notifications
- Log errors to console in development; integrate with error tracking in production

## Logging & Observability

- Use `console.error` for unexpected errors during development
- Integrate with an error tracking service (e.g., Sentry) for production
- Never log sensitive data (tokens, passwords, PII) — even in development

## Testing — Vitest + React Testing Library

- Use **Vitest** as the test runner (Vite-native)
- Use **React Testing Library** for component tests
- Test behavior, not implementation details — query by role, label, or text
- Mock API calls at the service layer, not at the Axios level
- Test hooks in isolation with `renderHook` when logic is complex
