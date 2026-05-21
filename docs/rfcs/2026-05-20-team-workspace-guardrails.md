# RFC: Team Workspace Guardrails — pre-commit, CI quality workflow, IDE configs

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-20 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **Stakeholders** | Octopus maintainers, teams that consume Octopus as the foundation for a versioned team workspace |

## Problem Statement

Teams that adopt Octopus as the foundation of a versioned workspace get strong coverage of code-assistant guardrails **inside the Claude Code loop** (via `hooks/hooks.json`) and a rich catalog of rules/skills/knowledge/templates. Three gaps remain for end-to-end deterministic enforcement against AI drift:

1. **No pre-commit framework installer** — `block-no-verify` stops the agent from bypassing pre-commit, but Octopus does not install or maintain a pre-commit framework (`pre-commit`, `lefthook`, `husky`). Copilot edits and human edits skip every Octopus hook because those run only inside the Claude Code tool loop.
2. **No CI quality workflow template** — `templates/github-actions/claude.yml` ships an agent-driven PR review, not structural quality enforcement (format/lint/commit-msg/test). When a human commits with `--no-verify`, the only remaining barrier is CI; today there is no template for it.
3. **No IDE config templates** — no `.editorconfig`, no `.vscode/settings.json`/`extensions.json` shipped. Visual reinforcement of the project's formatter/linter happens per-developer, not per-repo.

All three are deterministic, non-AI surfaces that an opinionated foundation should standardize. Solving them upstream avoids every adopting team rebuilding the same scaffolding.

## Proposed Approach

Add three artifacts to the Octopus default catalog, composed by one new intent bundle:

1. **`bundles/guardrails.yml`** — intent bundle that ties together the existing default hooks (`hooks: true`), the two new skills below, and signals the new CI template via a manifest flag.
2. **`skills/enforce-precommit/`** — skill that detects project stack(s) via file extensions, reads `rules/common/*` to infer the enforced checks, and writes/updates a pre-commit framework config (default: `pre-commit.com` for polyglot; `lefthook` and `husky` as documented alternatives). Idempotent; respects existing config and merges. Project-level extension via `enforce-precommit.local.md`.
3. **`skills/enforce-ide/`** — skill that writes a baseline `.editorconfig` aligned with the chosen formatter, and optionally `.vscode/settings.json` + `.vscode/extensions.json` per detected stack. Conservative defaults; respects existing files.
4. **`templates/github-actions/quality.yml`** — Quality-gate workflow that runs format-check + lint + commit-msg-lint + test on `pull_request`. Activated by `qualityWorkflow: true` in `.octopus.yml` (paritary with the existing `githubAction: true` flag). `setup.sh` materializes it analogously to `claude.yml`.

Adoption shape:

```yaml
# .octopus.yml in a consumer repo
agents: [claude, copilot]
hooks: true
qualityWorkflow: true
bundles:
  - starter
  - quality
  - docs
  - guardrails
```

## Alternatives Considered

### Alternative A — Team fork of Octopus

Each team forks Octopus and maintains its own bundle/skills/templates.

- **Pros:** maximum freedom; no upstream review cycle.
- **Cons:** forks drift from upstream; teams lose shared learnings; same three gaps get solved independently N times; defeats the "shared foundation" premise.

### Alternative B — Per-team external bundle consumed via URL/git ref

Octopus stays unchanged; teams ship their own `team-rules` repo that the project pulls via a sync hook.

- **Pros:** keeps Octopus minimal; team owns its catalog.
- **Cons:** introduces a second source of truth and a second update cadence; pre-commit/CI/IDE scaffolding is generic enough to live in Octopus default; "no loose skills, every skill maps to a bundle" convention favors upstreaming.

### Alternative C — Document the gap, do not ship

Add a docs section "how to wire pre-commit + CI + IDE alongside Octopus" without skills or templates.

- **Pros:** no new code surface to maintain.
- **Cons:** every team re-implements the wiring; deterministic enforcement remains team-by-team optional; defeats the "guardrails as code" goal.

## Trade-offs

**Gaining:**

- Octopus becomes end-to-end opinionated about deterministic enforcement (loop + git + CI + IDE), not just loop-level.
- Teams adopting Octopus as foundation get a single setup path: `.octopus.yml` with `bundles: [..., guardrails]` materializes all three.
- Convention drift between teams shrinks because the framework choice and CI shape are shared defaults.

**Giving up:**

- Octopus takes on opinion about which pre-commit framework is default (proposal: `pre-commit.com` for polyglot; alternatives documented).
- One more surface to maintain: pre-commit and IDE conventions evolve; both skills will need periodic refresh (already covered by `audit-config`).
- The CI template implies `act`-able testability and matrix support; non-GitHub platforms would need analogous templates later (out of scope for this RFC; same pattern as `claude.yml`).

## Open Questions

1. **Default pre-commit framework**: `pre-commit.com` (polyglot, mature, Python-installed) vs `lefthook` (fast, single binary, YAML config). Proposal: `pre-commit.com` default, `lefthook` documented alternative. Need maintainer signal.
2. **`enforce-ide` scope**: ship `.vscode/` opinions or only `.editorconfig`? `.vscode/settings.json` per-stack risks IDE-fragmentation politics. Proposal: `.editorconfig` always, `.vscode/` opt-in via skill argument or a second skill `enforce-ide-vscode`.
3. **CI flag naming**: `qualityWorkflow: true` (verbose) vs `qualityCI: true` (shorter) vs `qualityGate: true`. Proposal: `qualityWorkflow:` for paritary spelling with `githubAction:`.
4. **`guardrails` bundle category**: `intent` (parity with `quality`, `docs`) or `foundation` (parity with `starter`)? Proposal: `intent` — teams should opt-in deliberately, since this writes files to project roots outside Octopus-owned paths.
5. **`hooks: true` collision**: setting `hooks: true` inside a bundle vs at the manifest root. Today `hooks:` lives at root in `.octopus.yml`. The bundle could *recommend* `hooks: true` via documentation rather than override it. Proposal: bundle docs say "requires `hooks: true`"; `setup.sh` warns if user selects `guardrails` without enabling hooks.

## Decision

<!-- Filled after review -->
<!-- Approved | Revised | Rejected — YYYY-MM-DD -->

## Next Steps

After RFC approval:

1. **Spec**: `docs/specs/2026-05-20-team-workspace-guardrails.md` with concrete skill behavior, file layouts, and CI template content.
2. **Implementation PRs** (separate):
   - PR 1: `bundles/guardrails.yml` + bundle docs
   - PR 2: `skills/enforce-precommit/` (SKILL.md + REFERENCE.md if needed)
   - PR 3: `skills/enforce-ide/` (SKILL.md)
   - PR 4: `templates/github-actions/quality.yml` + `setup.sh` integration (`qualityWorkflow:` flag handling, mirror of `githubAction:` block around `setup.sh:1647-1700`)
3. **Site updates** under `site/src/content/docs/bundles/guardrails.mdx` and `site/src/content/docs/skills/{enforce-precommit,enforce-ide}.mdx`.
4. **Internal pilot**: adopt in one team repo, measure onboarding time + retrabalho rate, feed back into RFC v2.

Reference plan (motivating context): `/home/leonardo/.claude/plans/por-que-os-agentes-goofy-gosling.md`
Reference presentation (team-facing): `docs/specs/team-workspace-presentation.html`
