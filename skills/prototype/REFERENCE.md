# prototype — Reference

## The Logic Branch

For questions about state, logic, data model, or algorithm. The
artifact is a runnable terminal app:

- **Single entry point** — one command starts it
- **In-memory state only** — no DB, no files, no network, unless the
  network *is* the question
- **State surfaced after every action** — print what the system thinks
  happened so the user can see it
- **Stdin or command-line args for input** — no UI overhead

### Example layout

```
app/order-state/__prototype__/
  LOGIC.md         # the question + assumptions + how to run
  state.ts         # the in-memory state machine
  run.ts           # the read-eval-print loop
```

### Example LOGIC.md skeleton

```markdown
## Question
Can the order state machine distinguish "paid but unshipped" from
"shipped but unpaid" using a single status field, or do we need two?

## Assumptions
- No partial shipments (orders ship in one go)
- Refunds are out of scope for this prototype

## Run
$ bun run app/order-state/__prototype__/run.ts

Type a command (pay, ship, status, quit) and press enter.
Each command prints the resulting state.
```

## The UI Branch

For questions about visual layout, interaction feel, or copy. The
artifact is a single route serving multiple variants:

- **One file per variant**, or one component switched by a
  `?variant=` query param
- **All variants on one route** — the user toggles, not navigates
- **Mock data hard-coded inline** — no fetching unless fetching *is*
  the question
- **Variants must be radically different** — three variations of the
  same layout teach nothing; three different layouts teach a lot

### Example layout

```
app/checkout/__prototype__/
  UI.md            # the question + what each variant explores
  page.tsx         # the route, reads ?variant= and renders one of below
  variant-a.tsx    # accordion layout
  variant-b.tsx    # single-page-scroll layout
  variant-c.tsx    # modal-stack layout
```

### Example UI.md skeleton

```markdown
## Question
Which checkout layout reduces drop-off — accordion, single-scroll,
or modal-stack?

## Variants
- a: accordion (current production)
- b: single-page scroll
- c: modal-stack (one step per modal)

## Run
$ bun run dev
Open /checkout/__prototype__?variant=a (or b, or c)
```

## Where Prototypes Live

Prototypes live **next to their real destination**, in a
`__prototype__/` directory inside the area they will eventually
inform. Reasons:

- Locality — when the prototype answers its question, the relevant
  code is one directory away
- Visibility — anyone reading the area sees the prototype existed
- Disposability — deleting `__prototype__/` removes the prototype
  without grepping the tree

Never put prototypes at the repo root or under `prototypes/` —
that loses the locality benefit.

## State-Surface Examples

After every action, the logic-branch prototype prints:

```
> pay
state: { status: "paid", shipped: false, paidAt: 2026-05-19T12:00:00Z }

> ship
state: { status: "paid", shipped: true,  paidAt: ..., shippedAt: ... }

> status
state: { status: "paid", shipped: true,  paidAt: ..., shippedAt: ... }
```

If the user can run a command without seeing the state change, the
prototype is not surfacing enough. The whole point of the logic
branch is **observability over time**.
