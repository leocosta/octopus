---
name: test-component
description: >
  Component-level testing with Testing Library (React/Vue) and Vitest —
  behaviour through accessible queries and user-event, network-boundary
  mocking with MSW, and the line between component tests and end-to-end.
triggers:
  paths: ["**/*.test.tsx", "**/*.test.jsx", "**/__tests__/**", "**/*.spec.tsx"]
  keywords: ["testing-library", "rtl", "render", "screen", "user-event", "vitest"]
  tools: []
---

# Component Testing

## When to Use

- Writing tests for a component, hook, or form
- Choosing what belongs in a component test vs. an end-to-end test
- Fixing brittle tests that break on refactors (a smell — see below)
- Setting up the component-test harness for a new project

This is the component-layer counterpart to `test-e2e`. It tests a unit of UI
in isolation (rendered in jsdom), not the assembled app in a real browser.

## Core Principle — test behaviour, not implementation

Test what the user perceives and does, never internal state or call order.
A test that breaks when you rename a `useState` variable was testing the
wrong thing.

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

test("submits the form with valid data", async () => {
  const onSubmit = vi.fn();
  render(<StudentForm onSubmit={onSubmit} />);

  await userEvent.type(screen.getByLabelText("Name"), "Maria");
  await userEvent.click(screen.getByRole("button", { name: /save/i }));

  expect(onSubmit).toHaveBeenCalledWith(
    expect.objectContaining({ name: "Maria" }),
  );
});
```

## Query by accessibility

- Prefer `getByRole`, `getByLabelText`, `getByText` — in that order.
- Reach for `getByTestId` only when no semantic query exists. Needing it
  often is an accessibility gap in the component, not a testing limitation
  (see `frontend-patterns` — accessibility).
- Use `findBy*` for elements that appear asynchronously; never
  `waitForTimeout`.

## Simulate real users with user-event

- Use `@testing-library/user-event`, not `fireEvent`, for clicks, typing, and
  tabbing — it models real interaction (focus, key events) far more closely.
- `await` every interaction; user-event is async.

## Mock at the network boundary (MSW)

Mock HTTP with Mock Service Worker, not the service or `fetch`/`axios` layer.
The component exercises its real data path; only the network is faked.

```tsx
import { http, HttpResponse } from "msw";
import { server } from "@/test/server";

beforeEach(() => {
  server.use(
    http.get("/api/students", () =>
      HttpResponse.json([{ id: "1", name: "Maria" }]),
    ),
  );
});
```

## Testing hooks

Use `renderHook` for hooks with non-trivial logic; assert on the returned
value and status, never on internals.

```tsx
const { result } = renderHook(() => useStudents(), { wrapper: QueryWrapper });
await waitFor(() => expect(result.current.isSuccess).toBe(true));
expect(result.current.data).toHaveLength(3);
```

## What to test at this layer

| Target | Focus |
|--------|-------|
| Components | Renders correct content; handles user interaction |
| Hooks | Returns correct data; handles loading / error states |
| Forms | Validation messages; submit with valid and invalid data |
| States | Loading, error, empty, and success render paths |

## Component test vs. E2E — where the line is

- **Component test (here):** one component/hook in isolation, network mocked,
  fast, runs on every save. Every form-validation rule, every empty/error
  state, every conditional render.
- **E2E (`test-e2e`):** the assembled app in a real browser against a real
  backend. Critical user journeys end to end — login, checkout, the one flow
  that must never break.

Rule of thumb: if it's a rule or a state, test it here; if it's a journey
across pages, push it to `test-e2e`. Don't re-test every validation rule in E2E.

## Anti-Patterns

- **Asserting on CSS classes or styling** — that's not behaviour.
- **Asserting on internal `useState` values** or render/call order.
- **`fireEvent` for user actions** when `user-event` models them better.
- **Mocking the service/`axios` layer** instead of the network — it skips the
  component's real data path.
- **`waitForTimeout(n)`** — wait for a condition (`findBy*`, `waitFor`).
- **Testid-first queries** when a role/label query exists.
- **Re-testing in E2E** what a fast component test already covers.

## Integration with Other Skills

- **`frontend-patterns`** — the components/hooks under test are built there;
  accessible markup is what makes them queryable.
- **`test-e2e`** — the journey-level sibling; this skill stops at the
  component boundary.
- **`test-tdd`** — the red-green-refactor discipline; this skill supplies the
  vocabulary for the "what's worth testing" step at the component layer.
- Stack rules: `rules/typescript/testing.md`.
