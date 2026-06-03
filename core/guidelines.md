# Coding Guidelines

The coding standards are the always-loaded rules under `rules/common/` — they are
not repeated here (loading them twice wasted ~580 tokens every session, RM-117):

- `coding-style.md` — principles (KISS/DRY/YAGNI), code structure, naming, anti-patterns
- `patterns.md` — error handling and design patterns (Result, repository, service layer)
- `security.md` — secrets, input validation, injection prevention, authz
- `testing.md` — what to test, AAA structure, coverage
- `exceptions.md` — when a custom exception is justified (the creation gate)

Stack-specific rules layer on top in `rules/<language>/`.
