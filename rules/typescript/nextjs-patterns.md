# Next.js Patterns (App Router)

## Server vs Client Components

Default to Server Components. Add `"use client"` only when you need:
- Event handlers (`onClick`, `onChange`)
- Browser APIs (`useState`, `useEffect`, `useRef`)
- Third-party client-only libraries

Keep client components small and push them to the leaves of the tree.

## Layouts and Pages

```
app/
  layout.tsx          # Root layout (html, body, providers)
  page.tsx            # Home page
  dashboard/
    layout.tsx        # Dashboard shell (sidebar, nav)
    page.tsx          # Dashboard index
    students/
      page.tsx        # Student list
      [id]/
        page.tsx      # Student detail
```

- `layout.tsx` wraps child routes and preserves state across navigation.
- `page.tsx` is the routable entry point for each segment.
- `loading.tsx` and `error.tsx` for segment-level loading/error UI.

## Data Fetching

Fetch data in Server Components using `async/await`. No need for `useEffect`.

```tsx
// app/students/page.tsx (Server Component)
export default async function StudentsPage() {
  const students = await getStudents();
  return <StudentList students={students} />;
}
```

Use `fetch` with Next.js caching options or direct DB/service calls.

## Server Actions

Use Server Actions for mutations. Define with `"use server"`.

```tsx
// app/students/actions.ts
"use server";

export async function createStudent(formData: FormData) {
  const data = studentSchema.parse(Object.fromEntries(formData));
  await db.student.create({ data });
  revalidatePath("/students");
}
```

Invoke from Client Components via `action` prop or `useActionState`.

## Route Handlers

Use `app/api/` route handlers for webhooks, third-party callbacks, or custom endpoints:

```tsx
// app/api/webhooks/route.ts
export async function POST(request: Request) {
  const body = await request.json();
  // process webhook
  return Response.json({ ok: true });
}
```

## Middleware

Use `middleware.ts` at the project root for auth guards, redirects, or header injection. Keep it fast -- no heavy computation.

```tsx
// middleware.ts
export function middleware(request: NextRequest) {
  const token = request.cookies.get("session");
  if (!token) return NextResponse.redirect(new URL("/login", request.url));
}

export const config = { matcher: ["/dashboard/:path*"] };
```

## Dynamic Routes and Params

- `[id]` for dynamic segments, `[...slug]` for catch-all.
- Access params via the `params` prop (Server Components) or `useParams()` (Client).
- Use `generateStaticParams` for static generation of dynamic routes.
