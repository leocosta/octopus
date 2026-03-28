# Example: Continuous Learning for "Authentication" Domain

This example shows how the knowledge system works in practice.
Copy the `_template/` folder to create your own domain folders.

## Structure

```
knowledge/
├── INDEX.md                  # Domain router (see below)
└── authentication/
    ├── knowledge.md          # Confirmed facts
    ├── hypotheses.md         # Under investigation
    └── rules.md              # Auto-applied rules
```

## INDEX.md Entry

Add this to your project's `/knowledge/INDEX.md`:

| Domain | Path | Status |
|---|---|---|
| Authentication | `knowledge/authentication/` | Active |

## How It Evolves

### Phase 1: Initial observation → knowledge.md
```
[FACT-001] JWT tokens must use RS256, not HS256
  - Evidence: Security audit finding on 2026-03-20
  - Date: 2026-03-20
```

### Phase 2: New question → hypotheses.md
```
[HYP-001] Token refresh should happen proactively at 80% TTL
  - Predicted outcome: Fewer user-facing auth failures
  - Confirmed count: 2/5
  - Failed count: 0/3
  - Last tested: 2026-03-25
  - Evidence:
    - Task A: Reduced refresh errors by 40%
    - Task B: No user complaints about session expiry
```

### Phase 3: After 5 confirmations → rules.md
```
[RULE-001] Always use RS256 for JWT signing
  - Confirmed 5 times across: audit-fix, new-api, migration
  - Enforces: RS256 algorithm for all JWT tokens
  - Exception: None — this is security-critical
```
