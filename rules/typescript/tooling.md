# Tooling & Configuration

## TypeScript

- Enable `strict: true` in `tsconfig.json`. No exceptions.
- Use path aliases for clean imports:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  }
}
```

## Vite

- Use `vite.config.ts` with the React plugin.
- Configure path aliases to match `tsconfig.json`.
- Use `envPrefix: "VITE_"` to expose env vars to the client.

## ESLint & Prettier

- ESLint with `@typescript-eslint` and `eslint-plugin-react-hooks`.
- Prettier for formatting. No manual style debates.
- Run both in CI. Format on save locally.

## UI: shadcn/ui + Tailwind CSS

- Use shadcn/ui as the base component library. Add components via CLI:

```bash
npx shadcn-ui@latest add button dialog table
```

- Style with Tailwind utility classes. Avoid inline styles and CSS modules.
- Use `cn()` for conditional class merging:

```tsx
import { cn } from "@/lib/utils";

<div className={cn("rounded-lg p-4", isActive && "bg-primary text-white")} />
```

- Follow shadcn/ui composition patterns (`Card`, `CardHeader`, `CardContent`).

## Validation: Zod

Define schemas once, derive TypeScript types from them:

```tsx
import { z } from "zod";

const studentSchema = z.object({
  name: z.string().min(1, "Required"),
  email: z.string().email("Invalid email"),
  age: z.number().int().min(1).max(120),
});

type Student = z.infer<typeof studentSchema>;
```

Use `zodResolver` with react-hook-form:

```tsx
const form = useForm<Student>({ resolver: zodResolver(studentSchema) });
```

## API Client: Axios

Centralized instance with interceptors in `src/lib/api.ts`:

```ts
const api = axios.create({ baseURL: import.meta.env.VITE_API_URL });

api.interceptors.request.use((config) => {
  const token = getToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) redirectToLogin();
    return Promise.reject(error);
  }
);
```

Service functions return typed data, never raw Axios responses:

```ts
export const studentService = {
  getAll: (filters?: StudentFilters) =>
    api.get<Student[]>("/students", { params: filters }).then((r) => r.data),
};
```
