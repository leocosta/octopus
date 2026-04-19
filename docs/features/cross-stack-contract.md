# Cross-Stack Contract

Detects API-vs-frontend contract drift in multi-stack monorepos — the
silent bugs that only surface at integration runtime when a DTO field
renamed on the API side is never updated on the React / Astro side.

## When to use

Before merging any PR that touches your API and you want a sanity check
that the frontends are still in sync. Works well alongside
`money-review` and `security-scan` — all three emit the same report
format so reviews can be concatenated.

## Enable

```yaml
# .octopus.yml
skills:
  - cross-stack-contract

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
/octopus:cross-stack-contract                          # current branch vs main
/octopus:cross-stack-contract #123                     # a PR
/octopus:cross-stack-contract --stacks=api,app
/octopus:cross-stack-contract --only=endpoint-removed,dto
/octopus:cross-stack-contract --write-report
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

- `docs/cross-stack-contract/patterns.md` — append repo-specific
  endpoint / DTO / consumer patterns.

## Review before merge

The report is guidance, not a gate. It catches the drift the eye
misses; reviewers decide what to block.
