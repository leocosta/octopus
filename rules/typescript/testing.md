# Testing

## Stack

- **Vitest** as the test runner (Vite-native, fast).
- **React Testing Library** for component tests.
- **MSW (Mock Service Worker)** for API mocking at the network level.

## Principles

- Test behavior, not implementation. Never assert on internal state or hook internals.
- Query elements by accessibility: `getByRole`, `getByLabelText`, `getByText`.
- Avoid `getByTestId` unless no semantic query exists.

## Component Tests

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

test("submits student form with valid data", async () => {
  const onSubmit = vi.fn();
  render(<StudentForm onSubmit={onSubmit} />);

  await userEvent.type(screen.getByLabelText("Name"), "Maria");
  await userEvent.type(screen.getByLabelText("Email"), "maria@school.com");
  await userEvent.click(screen.getByRole("button", { name: /save/i }));

  expect(onSubmit).toHaveBeenCalledWith(
    expect.objectContaining({ name: "Maria", email: "maria@school.com" })
  );
});
```

## Testing Hooks

Use `renderHook` for complex hooks with non-trivial logic:

```tsx
import { renderHook, waitFor } from "@testing-library/react";

test("useStudents returns student list", async () => {
  const { result } = renderHook(() => useStudents(), { wrapper: QueryWrapper });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toHaveLength(3);
});
```

## API Mocking with MSW

Mock at the network level, not at the service/Axios layer:

```tsx
import { http, HttpResponse } from "msw";
import { server } from "@/test/server";

beforeEach(() => {
  server.use(
    http.get("/api/students", () =>
      HttpResponse.json([{ id: "1", name: "Maria" }])
    )
  );
});
```

## What to Test

| Layer | Test Focus |
|-------|-----------|
| Components | Renders correct content, handles user interaction |
| Hooks | Returns correct data, handles loading/error states |
| Forms | Validation messages, submission with valid/invalid data |
| Pages | Integration: data loads, key elements render |

## What NOT to Test

- CSS classes or styling details.
- Internal component state (`useState` values).
- Third-party library internals (shadcn/ui, React Query).
- Implementation order of function calls.
