# Security

> **Extend-only:** create `security.local.md` here to add rules. Do not weaken Octopus security defaults.

## Secrets Management

- **Never hardcode secrets** — use env vars or secret managers
- Add `.env*.local` to `.gitignore` — keep secrets out of version control
- Validate required secrets at startup — fail fast if missing
- Rotate any exposed credential immediately

## Input Validation

- Validate and sanitize **all external input** at boundaries
- Use schema-based validation (Zod, FluentValidation, Pydantic)
- Reject invalid input early — before processing or storing
- Never trust client-side validation alone

## Injection Prevention

- **Parameterized queries** — never concatenate user input into SQL
- Sanitize HTML output to prevent XSS
- Escape shell arguments when invoking commands
- Validate file paths to prevent directory traversal

## Authentication & Authorization

- **Least privilege** — minimum required permissions
- Protect endpoints by default — opt-out explicitly for public routes
- Short-lived tokens (JWT) with proper expiration
- Rate-limit authentication endpoints

## Dependency Management

- Keep dependencies current — audit for vulnerabilities
- Pin versions in production
- Review new dependencies — prefer well-maintained packages
- Remove unused dependencies promptly

## Error Handling

- Never expose stack traces, SQL, or internal paths in API responses
- Log detailed errors server-side; return safe messages to clients
- Never log sensitive data (passwords, tokens, PII, card numbers)
- Use correlation IDs for tracing without exposing internals

## Before Committing

1. No hardcoded secrets (API keys, passwords, tokens)
2. All user inputs validated
3. SQL injection prevented (parameterized queries)
4. XSS prevented (sanitized output)
5. Auth and authorization verified
6. Error messages don't leak sensitive data
