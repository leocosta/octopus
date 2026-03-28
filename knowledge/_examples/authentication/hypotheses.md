# Authentication Hypotheses

## Under Investigation
- [HYP-001] Token refresh should happen proactively at 80% TTL
  - Predicted outcome: Fewer user-facing auth failures
  - Confirmed count: 2/5
  - Failed count: 0/3
  - Last tested: 2026-03-25
  - Evidence:
    - Task A: Reduced refresh errors by 40%
    - Task B: No user complaints about session expiry
