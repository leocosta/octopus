---
name: e2e-testing
description: End-to-end testing patterns with Playwright for reliable, maintainable browser tests
triggers:
  paths: ["**/*.spec.ts", "**/*.spec.js", "**/*.test.ts", "cypress/**", "playwright/**"]
  keywords: []
  tools: []
---

# End-to-End Testing

## When to Use

- Setting up E2E tests for a new project
- Writing tests for critical user flows (auth, checkout, data mutations)
- Debugging flaky E2E tests
- Integrating E2E tests into CI/CD

## Project Structure

```
e2e/
├── tests/
│   ├── auth/
│   │   ├── login.spec.ts
│   │   └── registration.spec.ts
│   ├── students/
│   │   ├── create-student.spec.ts
│   │   └── list-students.spec.ts
│   └── payments/
│       └── checkout.spec.ts
├── pages/                    # Page Object Models
│   ├── login.page.ts
│   ├── students.page.ts
│   └── base.page.ts
├── fixtures/                 # Test data and custom fixtures
│   └── test-data.ts
├── helpers/                  # Shared utilities
│   └── auth.helper.ts
└── playwright.config.ts
```

## Page Object Model

Encapsulate page interactions behind a clean API:

```typescript
// pages/login.page.ts
export class LoginPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto("/login");
  }

  async login(email: string, password: string) {
    await this.page.getByLabel("Email").fill(email);
    await this.page.getByLabel("Password").fill(password);
    await this.page.getByRole("button", { name: "Sign in" }).click();
  }

  async expectError(message: string) {
    await expect(this.page.getByText(message)).toBeVisible();
  }
}
```

## Reliability Patterns

### Use Auto-Waiting Locators

```typescript
// GOOD — auto-waits for element
await page.getByRole("button", { name: "Save" }).click();

// BAD — fragile, no auto-wait
await page.click(".btn-save");
```

### Wait for Network When Needed

```typescript
// Wait for API response after form submission
await Promise.all([
  page.waitForResponse(resp => resp.url().includes("/api/students") && resp.status() === 201),
  page.getByRole("button", { name: "Save" }).click(),
]);
```

### Avoid Hardcoded Waits

```typescript
// BAD
await page.waitForTimeout(3000);

// GOOD — wait for specific condition
await page.waitForLoadState("networkidle");
await expect(page.getByText("Saved")).toBeVisible();
```

## Configuration

```typescript
// playwright.config.ts
export default defineConfig({
  testDir: "./e2e/tests",
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
  webServer: {
    command: "npm run dev",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

## CI Integration

- Run E2E tests in CI with `retries: 2` for resilience
- Use single worker in CI to avoid resource contention
- Upload traces and screenshots as artifacts on failure
- Use `webServer` config to auto-start the dev server

## Test Isolation

- Each test should be independent — no shared state between tests
- Use `beforeEach` for setup, not `beforeAll` (unless truly shared)
- Create test data via API calls in fixtures, not via UI
- Clean up test data after each test (or use isolated test accounts)

## What to Test E2E

**Always test:**
- Authentication flows (login, logout, session expiry)
- Critical business flows (checkout, data creation, approvals)
- Navigation and routing (deep links, protected routes)
- Error states (network failures, validation errors)

**Don't test E2E:**
- Unit logic (use unit tests)
- Every form validation rule (use component tests)
- Visual styling (use visual regression tools)
- Third-party integrations in detail (mock at boundary)

## Accessibility in E2E

- Use role-based locators (`getByRole`) — they enforce semantic HTML
- Add basic a11y checks: `await expect(page).toHaveTitle(/Students/)`
- Consider integrating `@axe-core/playwright` for automated a11y audits
