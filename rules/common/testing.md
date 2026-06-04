# Testing

> **Override:** create `testing.local.md` here to replace these entirely.

## Principles

- Test **behavior**, not implementation details
- A failing test should clearly indicate what went wrong
- Test names describe the scenario and expected outcome
- Integration tests for critical paths, unit tests for complex logic
- Keep tests independent — no shared mutable state

## Structure

- **AAA pattern**: Arrange, Act, Assert
- One logical assertion per test (multiple asserts OK if they verify one behavior)
- Descriptive names: `should_return_error_when_email_is_invalid`
- Group related tests by feature or behavior

## What to Test

- Happy paths for all critical user flows
- Edge cases: empty inputs, boundary values, null/undefined
- Error paths: invalid input, unauthorized access, network failures
- Business rules and domain logic
- State transitions and side effects

## What NOT to Test

- Framework or third-party library internals
- Trivial getters/setters with no logic
- Implementation details that may change (private methods, internal state)
- Exact UI layout or styling (unless visual regression)

## Test Data

- Use factories or builders — avoid hardcoded fixtures
- Each test creates its own data — no dependence on execution order
- Clean up after integration tests (or use transactions/containers)

## Coverage

- Target meaningful coverage, not a number — 80% is a guideline
- Uncovered code should be a conscious decision
- Critical paths (auth, payments, data mutations) need integration tests
