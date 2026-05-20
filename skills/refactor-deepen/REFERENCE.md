# refactor-deepen — Reference

## Canonical Vocabulary

This skill enforces a fixed vocabulary. Do not drift to "component",
"service", "boundary", "helper" when one of these applies:

| Term | Meaning |
|---|---|
| **Module** | A unit of code with a public interface and a private implementation |
| **Interface** | What callers see — types, names, contracts |
| **Implementation** | What is hidden behind the interface |
| **Depth** | Implementation complexity ÷ interface complexity. Higher is better |
| **Seam** | A place where the code can be split without bleeding context |
| **Adapter** | A translation layer between two stable interfaces |
| **Leverage** | How much downstream code benefits from one change at this point |
| **Locality** | Whether code that changes together lives together |

When in doubt, quote this table. Vocabulary drift is the most common
failure mode of architecture conversations.

## Shallow-Module Signals

During Step 2 (Explore), look for these patterns:

| Signal | Why it matters |
|---|---|
| Interfaces with N parameters where N matches the implementation's internal state | The interface is leaking the implementation — caller has to know everything |
| Helper files of < 50 lines extracted only for testability | The seam is hypothetical; testability could be addressed by testing the caller |
| Multiple adjacent files implementing one conceptual operation | Locality is broken — code that changes together does not live together |
| Pure functions used in exactly one place, exported for "reusability" | Premature DRY — the second use case has not appeared |
| Adapter layers with exactly one implementation | The adapter is the seam; one impl means the seam was hypothetical |
| Re-exports that only forward to one symbol | The module is a pass-through |
| "Manager" / "Service" / "Helper" suffix without a Module + Interface pair | Shallow naming, often shallow content |

A single signal is suggestive; two or more is a strong candidate.

## Deletion-Test Examples

### Example 1 — Pass-through utility

```
// utils/parseId.ts
export function parseId(raw: string) {
  return parseInt(raw, 10);
}
```

Used in 8 callers. **Deletion test**: each caller becomes
`parseInt(raw, 10)`. Complexity does not move; it disappears. The
module was pass-through. **Verdict: delete.**

### Example 2 — Single-call adapter

```
// repo/userAdapter.ts
export class UserRepoAdapter {
  constructor(private prisma: PrismaClient) {}
  findById(id: string) { return this.prisma.user.findUnique(...); }
}
```

Only `UserService` uses it. **Deletion test**: `UserService` calls
`prisma.user.findUnique` directly. The "swap the ORM later" claim
is hypothetical — the second adapter does not exist. **Verdict:
inline, hypothetical seam.**

### Example 3 — Real seam

```
// payment/gateway.ts (interface)
// payment/gateway.stripe.ts (impl 1)
// payment/gateway.pix.ts    (impl 2)
```

**Deletion test**: deleting the interface forces every caller to
branch by gateway type. The seam was real — two adapters exist.
**Verdict: keep, examine depth.** If the interface has 9 methods and
each impl uses only 2, the depth is low — narrow the interface.

### Example 4 — Locality break

```
// user/loader.ts    — reads from DB
// user/parser.ts    — turns row into domain object
// user/validator.ts — checks invariants
```

All three files change together for every domain change. **Deletion
test**: merging into `user/load.ts` reduces imports, keeps changes
local, and the new module is deeper (one interface, three internal
phases). **Verdict: consolidate.**
