# Coding Style

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
- One concept per file — avoid god files with mixed responsibilities

## Naming

- Names should reveal intent — `getActiveStudents()` not `getData()`
- Boolean variables/functions start with `is`, `has`, `can`, `should`
- Avoid abbreviations unless universally understood (`id`, `url`, `api`)
- Collections use plural names (`students`, `items`)
- Constants use UPPER_SNAKE_CASE or language convention

## Anti-Patterns to Avoid

- **God objects/functions** — doing too many things in one place
- **Premature optimization** — measure before optimizing
- **Magic numbers/strings** — use named constants
- **Catch-and-ignore** — swallowing exceptions silently
- **Copy-paste programming** — duplicating instead of abstracting
- **Over-engineering** — abstraction layers for problems that don't exist yet
- **Boolean parameters** — prefer options objects or separate functions
