# Skills

Reusable AI capabilities that provide specialized knowledge or audit
procedures. Skills are shipped as `SKILL.md` files; Claude Code loads
them natively, other assistants get them inlined into their output file.

## What each skill does

| Skill | What it does | Bundle | Tutorial |
|---|---|---|---|
| `adr` | Create and manage Architecture Decision Records (ADRs) to document significant technical decisions. | `starter` | — |
| `audit-all` | Composer skill — runs `security-scan`, `money-review`, `tenant-scope-audit`, and `cross-stack-contract` in parallel with shared file discovery and a consolidated report with cross-audit hotspots. | `quality-gates` | [audit-all.md](audit-all.md) |
| `backend-patterns` | Backend architecture decision patterns for multi-stack projects (Node.js, .NET, Python). | `dotnet-api` / `node-api` | — |
| `context-budget` | Audit and optimize AI-agent context-window usage to reduce token overhead and improve response quality. | `starter` | — |
| `continuous-learning` | Captures insights, tests hypotheses, and promotes confirmed patterns to rules — a learning loop that makes the agent sharper over time. | `docs-discipline` | — |
| `cross-stack-contract` | Detect API-vs-frontend contract drift in multi-stack monorepos (endpoints, DTOs, enums, status codes, auth rules, params). Produces a severity-tiered report with confidence labels. | `cross-stack` | [cross-stack-contract.md](cross-stack-contract.md) |
| `dotnet` | .NET backend architecture patterns, conventions, and decision trees for ASP.NET Core projects. | `dotnet-api` | — |
| `e2e-testing` | End-to-end testing patterns with Playwright for reliable, maintainable browser tests. | `dotnet-api` / `node-api` | — |
| `feature-lifecycle` | Guides the complete documentation lifecycle of a feature — from RFC through spec, implementation, ADR capture, and knowledge extraction. | `starter` | [feature-lifecycle.md](feature-lifecycle.md) |
| `feature-to-market` | Turn a completed feature (RM / spec / PR) into a versioned multi-channel launch kit under `docs/marketing/launches/` — posts, email, LP copy, commercial changelog, video script, and optional images. | `growth` | [feature-to-market.md](feature-to-market.md) |
| `money-review` | Pre-merge audit of money-touching code: numeric types, rounding, cents tests, env-var drift, payment idempotency, webhook signatures, fee-disclosure coupling. | `quality-gates` | [money-review.md](money-review.md) |
| `plan-backlog-hygiene` | Scan `plans/` + `docs/roadmap.md` for orphans, concluded-but-not-archived plans, duplicates, broken links, roadmap orphans, and stale items. `--fix` archives safely. | `docs-discipline` | [plan-backlog-hygiene.md](plan-backlog-hygiene.md) |
| `release-announce` | Themed release announcement kit for existing users — landing HTML, channel messages, slide deck, 9 preset themes. | `growth` | [release-announce.md](release-announce.md) |
| `security-scan` | Security audit checklist for AI-agent configurations, environment variables, and project dependencies. | `quality-gates` | — |
| `tenant-scope-audit` | Pre-merge audit of multi-tenant data-scope enforcement: query filters, new DbContext entities, raw SQL, controller ownership, admin endpoints. Blocks likely data-leak paths. | `quality-gates` | [tenant-scope-audit.md](tenant-scope-audit.md) |

Pair-ups:

- `security-scan` + `money-review` + `cross-stack-contract` + `tenant-scope-audit`
  share the same `🚫 Block / ⚠ Warn / ℹ Info` output format with confidence
  labels — concatenate them into one PR comment without extra formatting work.
- `feature-lifecycle` + `feature-to-market` cover the path from *plan* to
  *announce*.
- `plan-backlog-hygiene` pairs with the `schedule` skill for a monthly
  cron run.

## How it works

1. Add skills to `.octopus.yml`:
   ```yaml
   skills:
     - adr
     - e2e-testing
     - money-review
   ```
2. Run `octopus setup`.
3. **Claude Code**: skills are symlinked to `.claude/skills/<name>/` with a
   `SKILL.md` file each.
4. **Other agents**: skill content is appended to the agent's output file.

## Adding custom skills

1. Create a directory: `skills/<name>/` at the Octopus source.
2. Add a `SKILL.md` file with frontmatter:
   ```markdown
   ---
   name: <name>
   description: >
     One-line description of what the skill does — shown in the wizard
     and skills catalog.
   ---

   # <Skill title>

   (body)
   ```
3. Add `- <name>` to the `skills:` list in `.octopus.yml`.
4. Register in `cli/lib/setup-wizard.sh` (items array, hints, legend) so
   the setup wizard shows the skill with its one-line hint.
5. Add a tutorial at `docs/features/<name>.md` when the skill is
   user-facing and worth a dedicated page. Link it from the table above.
