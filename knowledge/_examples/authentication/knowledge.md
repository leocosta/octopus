# Authentication Knowledge

## Confirmed Facts
- [FACT-001] JWT tokens must use RS256, not HS256
  - Evidence: Security audit finding on 2026-03-20
  - Date: 2026-03-20

## Anti-Patterns
- [ANTI-001] Never store JWT tokens in localStorage
  - Example: `localStorage.setItem('token', jwt)`
  - Reason: Vulnerable to XSS attacks — use httpOnly cookies instead
