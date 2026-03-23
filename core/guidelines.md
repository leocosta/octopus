# Coding Guidelines

## Principles

- **Readability over cleverness** — code is read far more than it is written
- **KISS** — the simplest solution that works is usually the best
- **DRY** — don't repeat yourself, but don't abstract prematurely; three occurrences before extracting
- **YAGNI** — don't build for hypothetical future requirements
- **Single Responsibility** — each function, class, or module should do one thing well
- **Fail fast** — detect and report errors as early as possible

## Code Structure

- Keep functions short and focused — if it needs a comment to explain a section, extract it
- Limit function parameters — more than 3 usually means you need an options/config object
- Use early returns (guard clauses) to reduce nesting
- Group related code together — what changes together lives together
- Delete dead code — don't comment it out (git has history)

## Error Handling

- Handle errors at the appropriate level — don't catch and ignore
- Use typed/structured errors, not generic strings
- Validate at system boundaries (user input, API responses, external data)
- Trust internal code — don't add defensive checks for impossible states

## Security

- Never hardcode secrets — use environment variables
- Validate and sanitize all external input
- Use parameterized queries — never concatenate user input into SQL/queries
- Apply the principle of least privilege
- Keep dependencies up to date — audit regularly for vulnerabilities

## Testing

- Write tests for behavior, not implementation details
- A failing test should clearly indicate what went wrong
- Test names should describe the scenario and expected outcome
- Prefer integration tests for critical paths, unit tests for complex logic
- Keep tests independent — no shared mutable state between tests

## Anti-Patterns to Avoid

- **God objects/functions** — doing too many things in one place
- **Premature optimization** — measure before optimizing
- **Magic numbers/strings** — use named constants
- **Catch-and-ignore** — swallowing exceptions silently
- **Copy-paste programming** — duplicating instead of abstracting
- **Over-engineering** — abstraction layers for problems that don't exist yet
- **Boolean parameters** — prefer options objects or separate functions
