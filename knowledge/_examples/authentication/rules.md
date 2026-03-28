# Authentication Rules

## Auto-Applied Rules
- [RULE-001] Always use RS256 for JWT signing
  - Confirmed 5 times across: audit-fix, new-api, migration
  - Enforces: RS256 algorithm for all JWT tokens
  - Exception: None — this is security-critical
