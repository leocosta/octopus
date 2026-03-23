# Security

## Secrets Management

- **Never hardcode secrets** — use environment variables or secret managers
- Add `.env*.local` to `.gitignore` — secrets must not enter version control
- Validate required secrets exist at startup — fail fast if missing
- Rotate any potentially exposed credential immediately

## Input Validation

- Validate and sanitize **all external input** at system boundaries
- Use schema-based validation (Zod, FluentValidation, Pydantic)
- Reject invalid input early — before processing or storing
- Never trust client-side validation alone

## Injection Prevention

- Use **parameterized queries** — never concatenate user input into SQL
- Sanitize HTML output to prevent XSS
- Escape shell arguments when invoking system commands
- Validate file paths to prevent directory traversal

## Authentication & Authorization

- Apply the **principle of least privilege** — minimum required permissions
- Protect all endpoints by default — explicitly opt-out for public routes
- Use short-lived tokens (JWT) with proper expiration
- Implement rate limiting on authentication endpoints

## Dependency Management

- Keep dependencies up to date — audit regularly for vulnerabilities
- Pin dependency versions in production
- Review new dependencies before adding — prefer well-maintained packages
- Remove unused dependencies promptly

## Error Handling

- Never expose stack traces, SQL, or internal paths in API responses
- Log detailed errors server-side, return safe messages to clients
- Never log sensitive data (passwords, tokens, PII, credit card numbers)
- Include correlation IDs for request tracing without exposing internals

## Before Committing

1. No hardcoded secrets (API keys, passwords, tokens)
2. All user inputs validated
3. SQL injection prevention (parameterized queries)
4. XSS prevention (sanitized output)
5. Authentication and authorization verified
6. Error messages don't leak sensitive data
