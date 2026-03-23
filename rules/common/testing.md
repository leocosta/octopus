# Testing

## Principles

- Write tests for **behavior**, not implementation details
- A failing test should clearly indicate what went wrong
- Test names should describe the scenario and expected outcome
- Prefer integration tests for critical paths, unit tests for complex logic
- Keep tests independent — no shared mutable state between tests

## Structure

- Follow the **AAA pattern**: Arrange, Act, Assert
- One logical assertion per test — multiple asserts are fine if they verify the same behavior
- Name tests descriptively: `should_return_error_when_email_is_invalid`
- Group related tests by feature or behavior

## What to Test

- Happy paths for all critical user flows
- Edge cases: empty inputs, boundary values, null/undefined
- Error paths: invalid input, unauthorized access, network failures
- Business rules and domain logic
- State transitions and side effects

## What NOT to Test

- Framework internals or third-party library behavior
- Trivial getters/setters with no logic
- Implementation details that may change (private methods, internal state)
- Exact UI layout or styling (unless visual regression testing)

## Test Data

- Use factories or builders for test data — avoid hardcoded fixtures
- Each test should create its own data — no dependence on test execution order
- Clean up after integration tests (or use transactions/containers)

## Coverage

- Target meaningful coverage, not a number — 80% is a guideline, not a goal
- Uncovered code should be a conscious decision, not an oversight
- Critical paths (auth, payments, data mutations) must have integration tests
