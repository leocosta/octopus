# Cross-Stack Contract

Detects API-vs-frontend contract drift in multi-stack monorepos — the
silent bugs that only surface at integration runtime when a DTO field
renamed on the API side is never updated on the React / Astro side.

## When to use

Before merging any PR that touches your API and you want a sanity check
that the frontends are still in sync. Works well alongside
`audit-money` and `audit-security` — all three emit the same report
format so reviews can be concatenated.

## Enable

```yaml
# .octopus.yml
skills:
  - audit-contracts

# Optional: declare the stack roots explicitly.
# If omitted, the skill auto-detects from the filesystem.
stacks:
  api: api/src
  app: app/src
  lp: lp/src
```

Run `octopus setup`.

## Use

```
/octopus:audit-contracts                          # current branch vs main
/octopus:audit-contracts #123                     # a PR
/octopus:audit-contracts --stacks=api,app
/octopus:audit-contracts --only=endpoint-removed,dto
/octopus:audit-contracts --write-report
```

## Inspection checks

- **C1 endpoint-added** — new endpoint without a consumer (ℹ Info).
- **C2 endpoint-removed** — frontend still calls an endpoint that was
  removed or renamed (🚫 Block).
- **C3 dto** — a DTO field was changed on the API; the TypeScript
  twin still declares the old shape (⚠ Warn).
- **C4 enum** — enum members added/removed without the frontend union
  being updated (⚠ Warn).
- **C5 status** — response status code changed on an existing
  endpoint (ℹ Info).
- **C6 auth** — `[Authorize]` / `[AllowAnonymous]` / guard changed
  (⚠ Warn always — re-verify the frontend flow).
- **C7 params** — path or query param added/removed/renamed while a
  live call site still uses the old shape (⚠ Warn).

Every finding is labeled with a confidence level (`high` / `medium` /
`low`) so reviewers can prioritize.

## Overrides

- `docs/audit-contracts/patterns.md` — append repo-specific
  endpoint / DTO / consumer patterns.

## Review before merge

The report is guidance, not a gate. It catches the drift the eye
misses; reviewers decide what to block.
