# State Management

## Server State: TanStack Query (React Query 5)

All server data flows through TanStack Query. Never call API functions directly in components.

### Query Keys

Convention: `[domain, ...params]`

```ts
["students"]                    // list all
["students", { page: 1 }]      // filtered list
["students", id]                // single item
["students", id, "grades"]     // nested resource
```

### One Hook per Domain Query

```tsx
// features/students/hooks/useStudents.ts
export function useStudents(filters?: StudentFilters) {
  return useQuery({
    queryKey: ["students", filters],
    queryFn: () => studentService.getAll(filters),
  });
}
```

### Mutations with Invalidation

```tsx
export function useCreateStudent() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: studentService.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["students"] });
    },
  });
}
```

- Always invalidate related queries on success.
- Use `onError` for toast notifications on failure.
- Use optimistic updates only when UX demands instant feedback.

## Client State: Zustand

Use Zustand for UI state that is not server data (sidebar open, selected filters, theme).

```tsx
// stores/uiStore.ts
import { create } from "zustand";

interface UIState {
  sidebarOpen: boolean;
  toggleSidebar: () => void;
}

export const useUIStore = create<UIState>((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
}));
```

### Guidelines

- One store per concern (UI, auth, feature-specific transient state).
- Keep stores small. If a store grows past ~10 fields, split it.
- Never duplicate server state in Zustand. TanStack Query is the source of truth.

## Avoid Prop Drilling

- Reach for hooks (`useStudents()`, `useUIStore()`) instead of passing data through 3+ component layers.
- Use React Context only for cross-cutting concerns (theme, locale) that change infrequently.
- Context is not a state manager. Pair it with `useReducer` if you need complex dispatch logic.
