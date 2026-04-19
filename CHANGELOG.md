# Changelog

All notable changes to this project will be documented in this file.

## [1.8.0] - 2026-04-19

✨ New `release-announce` skill turns one or more refs (tags, tag ranges, RM IDs) into a themed release announcement kit aimed at **existing users** — a distinct job from `feature-to-market`, which handles acquisition and external audiences. Inputs can be a single version (`v1.7.0`), a range (`v1.5.0..v1.7.0`), or an RM ID (`RM-008`); default is since the last tagged release. Output is two-tiered: **canonical artifacts** (`index.html` themed landing page, `notes.md` plain fallback, `theme.yml` snapshot for reproducibility) plus **paste-ready channel messages** under `channels/` for email, Slack, Discord, in-app banner, status page, X/Twitter thread, WhatsApp, and an autocontained slide deck with keyboard nav and print-to-PDF.

🎨 Nine preset themes ship in v1 — `classic` (neutral newsletter default), `jade` (calm green), `dark` (modern high-contrast), `bold` (vibrant with oversized display), `newsletter` (text-heavy serif), `sunset` (warm orange/pink), `ocean` (cool blues), `terminal` (green mono-on-black dev aesthetic), and `paper` (editorial cream/browns). Each theme is a YAML file declaring palette, typography, layout (hero / grouping / density), and voice (tone / persona) tokens. Users pick via `.octopus.yml theme:` or per-run `--theme=<name>`. `--channels=<list>` controls the channel subset; default `email,slack,in-app-banner`. `--audience=<user|developer|executive>` tunes copy voice.

🔧 `--design-from="<prompt>"` optionally invokes the `frontend-design` skill to synthesize a custom theme YAML on the fly (e.g. `--design-from="retro arcade synthwave"`). The generated theme is persisted to `docs/release-announce/themes/<slug>.yml` and reusable via `--theme=<slug>` in subsequent runs. Default path stays deterministic — `frontend-design` is invoked only via `--design-from`, never for plain rendering.

📝 Slides template ships with ≤40 lines of vanilla JS (keyboard `→`/`←`/`Space`/`PageUp`/`PageDown`, touch swipe, URL hash persistence, print-to-PDF via `@page` landscape), inline CSS, no external assets. Email template uses bulletproof patterns (inline CSS, `<table>` layout, no `<script>`/`<style>` in body). The skill joins the `growth` bundle next to `feature-to-market`, covers acquisition + retention in one bundle. 12 structural tests guard skill content, theme shape, template tokens, slides JS budget, and wizard / bundle / README / skills.md integration.

## [1.7.0] - 2026-04-19

✨ Introduces **bundles** as the primary setup path. The wizard's Quick mode (default) now asks 4–6 yes/no persona questions ("Is this a SaaS product for external customers?", "Does your team produce marketing content?", "Primary backend is .NET?") and maps each positive answer to a curated bundle of skills + roles + rules. Seven bundles ship in v1: `starter` (foundation — `adr`, `feature-lifecycle`, `context-budget`; always included), four intent bundles (`quality-gates` → security-scan + money-review + tenant-scope-audit + backend-specialist role; `growth` → feature-to-market + social-media role; `docs-discipline` → plan-backlog-hygiene + continuous-learning + tech-writer role; `cross-stack` → cross-stack-contract + backend + frontend specialists), and two stack bundles (`dotnet-api`, `node-api`). Users can declare `bundles: [...]` in `.octopus.yml` and the expansion happens at setup time — a new user never needs to memorize the 13-skill catalog to get a sensible config. Power users still pick Full mode or mix explicit `skills:` / `roles:` on top of bundles; all user-explicit entries are additive (bundles never remove selections).

🔧 Implementation: new `OCTOPUS_BUNDLES` array parsed by `parse_octopus_yml`, `_load_bundle` reads a single YAML via python3, `expand_bundles` unions components across bundles with `_dedupe_array` preserving first-seen order. The expansion runs before any delivery function, so `deliver_skills` / `deliver_roles` / `deliver_mcp` stay oblivious to bundles — the feature is purely a preprocessing layer. New `_wizard_sub_bundles()` reads each bundle's `persona_question` and asks y/n; the Quick-mode flow now takes three grouped steps (Agents → Bundles → Workflow) instead of a one-shot 3-question form. The manifest writer emits `bundles:` when the wizard picked any, and skips emitting expanded `skills:` / `roles:` lists in that case.

📝 Docs: new `docs/features/bundles.md` tutorial covers Enable / Combining / Authoring / the new-skill convention. `docs/features/skills.md` gains a Bundle column showing membership for every skill. README intro, Quick Start, and Features table all surface bundles as the primary path. `templates/spec.md` gains a required `Bundle:` field in the "Context for Agents" section, enforcing the convention that every future skill declares bundle membership in its spec — no loose skills drift into the catalog without users discovering them.

🧪 New `tests/test_bundles.sh` runs nine assertions: bundle metadata presence, persona-question coverage for intent/stack, parser recognizes `bundles:`, loader populates component arrays, unknown bundle aborts loudly, union across multiple bundles, de-duplication of overlapping contributions, preservation of user-explicit entries, and full manifest round-trip (bundles-only YAML expands to the expected 6 skills + roles).

## [1.6.0] - 2026-04-19

✨ New `tenant-scope-audit` skill catches the systemic data-leak risk in multi-tenant SaaS codebases: a query without a tenant filter returns rows from every tenant. Given a branch or PR, the skill resolves the diff against a base, reads the optional `.octopus.yml` `tenantScope:` config (fields `field` / `filter` / `context` / `entities`, with defaults `TenantId` / `AppQueryFilter` / `AppDbContext`), identifies tenant-relevant files via path tokens (`Controller`, `Service`, `DbContext`, `Queries`, …) and content heuristics, and runs six inspection checks. T1 (`query-without-filter`) blocks on `IgnoreQueryFilters()` calls without a preceding `// tenant-override: <reason>` marker; T2 (`dbcontext-missing-filter`) blocks on new `DbSet<X>` entries lacking `HasQueryFilter` configuration; T3 (`raw-sql-no-filter`) blocks on `FromSqlRaw` / `ExecuteSqlRaw` / `Database.SqlQuery` whose SQL literal does not restrict by the tenant field. T4 (`id-from-route-no-ownership`) warns when a controller action accepts an id from the route and calls `.FindAsync(id)` on a tenant-scoped DbSet without a known ownership helper; T5 (`join-to-unfiltered-table`) warns on LINQ joins into a global table without tenant restriction; T6 (`cross-tenant-admin-endpoint`) warns on `[AllowAnonymous]` / `[Authorize(Roles = "Admin")]` methods that touch tenant-scoped data without a `// across-tenants: <reason>` marker.

🎨 Every finding carries a `confidence` label (`high` / `medium` / `low`) for triage parity with `cross-stack-contract`. The report format matches the existing `money-review` / `cross-stack-contract` / `security-scan` output (`🚫 Block / ⚠ Warn / ℹ Info`) plus a one-line config trailer showing which tenant field / filter / context were in effect. `--write-report` persists to `docs/reviews/YYYY-MM-DD-tenant-<slug>.md`; `--only=<checks>` runs a subset; `--base=<branch>` overrides the default `main`.

📝 Ships with default regex tokens for EF raw-SQL helpers, admin role markers, and override-marker comment grammar. Override cascade at `docs/tenant-scope-audit/patterns.md`. Tutorial at `docs/features/tenant-scope-audit.md` documents the `tenant-override:` and `across-tenants:` comment contracts. 8 structural tests, wizard + README + `skills.md` descriptions-table row integration. All four audit skills (`security-scan`, `money-review`, `cross-stack-contract`, `tenant-scope-audit`) now share one output format, so a combined PR comment concatenates without extra formatting.

## [1.5.1] - 2026-04-19

🐛 Three bugs in `.claude/settings.json` generation that could prevent Claude Code from loading the file. First, hook commands were emitted as relative paths (`octopus/hooks/pre-tool-use/block-no-verify.sh`) that do not resolve from the project's working directory — Claude Code would try to run a non-existent script. `deliver_hooks` in `setup.sh` now rewrites the `octopus/hooks/` prefix to the absolute Octopus install root (`$OCTOPUS_DIR/hooks/`), so every hook command is an absolute path that executes regardless of CWD. Second, `hooks/hooks.json` shipped a `PostToolUseFailure` event that is not part of Claude Code's documented hook schema; its presence could invalidate the settings.json on strict validation. The event and its companion `mcp-health` hook are removed. Third, `deliver_boris_settings` wrote experimental keys (`worktree`, `autoMemory`, `autoDream`, `sandbox`) at the top of settings.json plus `permissionMode: "auto"`, none of which are accepted values in Claude Code's schema. The function now whitelists only the schema-documented keys (`permissionMode`, `outputStyle`) and normalizes `permissionMode=auto` to `default`. The related features still ship (the dream subagent is delivered as a Claude agent file, the batch skill is an independent skill, etc.) — they just do not pollute `settings.json` with unrecognized keys.

🧪 New `tests/test_hooks_injection.sh` guards the three invariants: every hook command starts with `/`, no invalid events land in `settings.json`, and Boris-tip passthroughs are filtered + normalized correctly.

## [1.5.0] - 2026-04-19

✨ New `plan-backlog-hygiene` skill keeps the planning surface honest over time. Repos that lean on the feature-lifecycle accumulate plans, specs, and research docs faster than teams archive them — Tatame's `plans/` has grown past 50 files. The skill walks the planning directory (autodetected as `plans/`, `docs/plans/`, or `docs/superpowers/plans/`, or overridden via the new `.octopus.yml` `plansDir:` field), parses `docs/roadmap.md`, and cross-references the two. Six hygiene checks land in v1: orphan plans with no RM/PR/issue/spec reference (H1, Info), plans for already-completed RMs still sitting outside `archive/` (H2, Warn — auto-fixable), duplicate plans for the same RM-NNN (H3, Warn), broken internal links to missing specs/research/ADRs (H4, Warn), roadmap RMs in progress without a matching plan file (H5, Info), and plans unchanged longer than `--stale-days` (H6, Info, default 90).

🔧 `--fix` applies a single reversible action: for H2 matches, move the plan to `<plansDir>/archive/YYYY-MM/<filename>` using `git mv` so history is preserved. The move is staged but not committed, so `git restore --staged` undoes cleanly. A clean working tree is required. Other checks are never auto-fixed — H1/H3/H4/H5/H6 all need human judgment. `--write-report` persists the report to `docs/reviews/YYYY-MM-DD-hygiene.md`; `--only=<checks>` runs a subset; `--stale-days=<n>` tunes H6.

📝 Output format matches `money-review` and `cross-stack-contract` so a monthly "hygiene digest" PR can concatenate all three reports into one comment. Ships with default regex for RM/PR/issue/internal-link detection, roadmap status parsing (recognizes `completed`, `in progress`, `proposed`, `blocked`), an archive convention, tutorial at `docs/features/plan-backlog-hygiene.md`, 8 structural tests, and wizard + README integration. Pairs naturally with the `schedule` skill for monthly cron runs.

## [1.4.0] - 2026-04-19

✨ New `cross-stack-contract` skill detects API-vs-frontend contract drift in multi-stack monorepos — the silent bugs that only surface at integration runtime when a DTO field renamed on the .NET side is never updated on the React or Astro twin. Given a branch or PR, the skill partitions the diff by stack (via `.octopus.yml` `stacks:` map or autodetection over `api/`, `apps/api/`, `backend/`, `server/` for the API and conventional paths for React/Vue/Angular and Astro/Next landing pages), extracts contract intent tokens from the API diff (endpoint paths, DTO/record names, enum names, route attributes, auth annotations, param lists), and grep-matches them against frontend usage. Seven drift classes land in v1: endpoint additions without a consumer (C1, Info), endpoint removals/renames still called by a frontend (C2, Block), DTO field drift (C3, Warn), enum member desync (C4, Warn), response status code changes (C5, Info), authorization rule changes (C6, Warn always), and path/query param shifts that break live call sites (C7, Warn).

🎨 Every finding carries a **confidence** label (`high`/`medium`/`low`) so reviewers can triage heuristic matches quickly. The output format is the same three-heading severity markdown emitted by `money-review` and `security-scan`, so three audits can be concatenated into a single PR comment without extra formatting work. `--write-report` persists the report to `docs/reviews/YYYY-MM-DD-contract-<slug>.md` with frontmatter listing the stacks compared and the summary counts. `--stacks=<list>` restricts the comparison; `--only=<checks>` runs a subset of C1–C7.

📝 Ships with default endpoint/DTO/consumer patterns for .NET (ASP.NET Controllers, Minimal API), Node (Express, Fastify, Hono, NestJS, Astro file routes), React / Vue / Angular / Astro frontends, and frontend consumer idioms (fetch/axios/ky, React Query/SWR, generated SDKs). Override cascade at `docs/cross-stack-contract/patterns.md`. Tutorial at `docs/features/cross-stack-contract.md`, 8 structural tests, wizard + README integration.

## [1.3.0] - 2026-04-19

✨ New `money-review` skill audits money-touching code before merge. It resolves a branch or PR against a base, isolates money-touched files via filename and regex heuristics (tokens like `billing`, `payment`, `split`, `asaas`, `pix`, `webhook`, `fee`), and runs seven inspection families: numeric type safety (T1 — flag `float`/`double`/`number` for currency), explicit rounding strategy (T2), cents coverage in tests (T3 — require non-round literals like `0.01`, `199.99`), env-var consistency across sandbox and production (T4 — block when a new `*_PERCENT`/`*_FEE`/`*_RATE` exists in one environment but not the other), payment-call idempotency (T5 — flag POST calls lacking `Idempotency-Key` or `externalReference`), webhook signature verification (T6 — block new `/webhook` endpoints without a verifier helper), and fee/tax disclosure coupling (T7 — warn when a fee change lands without a spec mentioning disclosure).

🎨 Output is a severity-tiered markdown report (`🚫 Block / ⚠ Warn / ℹ Info`) designed to paste into a PR comment as-is. With `--write-report`, the same content is persisted to `docs/reviews/YYYY-MM-DD-money-<slug>.md` with frontmatter for traceability. The `--only=<families>` flag restricts the scan to a subset; `--base=<branch>` overrides the default `main`.

📝 Ships with embedded default patterns (`skills/money-review/templates/patterns.md`), provider idioms for Asaas / Stripe / Mercado Pago (`templates/providers.md`), a three-level override cascade (`docs/money-review/patterns.md` → `docs/MONEY_REVIEW_PATTERNS.md` → embedded), a tutorial at `docs/features/money-review.md`, and 8 structural tests guarding skill / command / wizard integration. Composes with the existing `security-scan` skill — run both on any billing PR.

## [1.2.0] - 2026-04-19

✨ New `feature-to-market` skill turns a completed feature (RM-NNN, spec path, research path, or PR) into a versioned multi-channel launch kit under `docs/marketing/launches/YYYY-MM-DD-<slug>/`. The kit bundles Instagram, LinkedIn and X posts, a launch email, landing-page copy, a commercial changelog entry, and a 30–60s video script — each rendered from per-channel templates with placeholders populated from the resolved feature context. Invocation is a single slash command (`/octopus:feature-to-market <ref>`) with flags for channel selection, dry-run, forced angle, and regeneration. Brand and voice pull from a three-level override cascade: `docs/marketing/<name>.md` (canonical) → `docs/<NAME>.md` (uppercase compat with repos that already keep these files at the docs root) → embedded defaults shipped with the skill.

🎨 Optional image generation stays free by default: `GEMINI_API_KEY` (free tier at aistudio.google.com) is the preferred provider, with Pollinations.ai as a zero-setup fallback and graceful degradation to prompts-only when neither is available. Brand palette and logo constraints from `brand.md` are injected into every prompt; aspect ratios are pre-tuned per channel (1:1 IG, 1.91:1 LI, 16:9 X card, 16:9 LP hero).

📝 Tutorial lands at `docs/features/feature-to-market.md`, README skills list and the setup wizard (`cli/lib/setup-wizard.sh`) gain the new entry, and 13 structural tests guard file layout, frontmatter, documented sections, and wizard registration.

## [1.1.1] - 2026-04-18

🔧 Cleanup delivery closing RM-019, RM-020 and RM-021. `install.sh` no longer embeds a HEREDOC copy of the `bin/octopus` shim — the installer now copies the shim straight from the extracted release tree, removing 307 lines and eliminating the drift risk between the two sources. The release pipeline in `.github/workflows/build-release.yml` signs the published tarball with GPG and uploads `octopus-<tag>.tar.gz.asc` alongside the existing `.sha256`, closing the loop on RM-009's consumer-side verification (requires `OCTOPUS_RELEASE_GPG_KEY` and `OCTOPUS_RELEASE_GPG_PASSPHRASE` to be provisioned as repo secrets — see `docs/specs/release-signing-pipeline.md`).

🧪 Four tests that had been waved through as "pre-existing failures" since before v1.0.0 are now fixed. They referenced functions renamed during earlier refactors (`generate_claude`, `inject_mcp_servers`), missed a pipeline step (`collect_gitignore_entries`), or used assertions that the current delivery contract outgrew. The full test suite now reports **19/19 green** on a clean checkout.

## [1.1.0] - 2026-04-18

Consolidated delivery of RM-011 through RM-018.

✨ Seven new manifest fields expose Boris Cherny's Claude Code tips as first-class Octopus configuration. `worktree`, `memory`, `dream`, `sandbox` and `permissionMode`/`outputStyle` flow through to `.claude/settings.json` as passthroughs. `githubAction: true` idempotently scaffolds `.github/workflows/claude.yml` for automated PR review. The new `batch` skill documents a fan-out pattern for applying the same prompt across many targets in isolated git worktrees, and a `dream` subagent (Haiku, Read/Write only) ships to consolidate and prune stale memory entries.

✨ Install scopes land as RM-018. A new `--scope=repo|user` flag (plus `OCTOPUS_SCOPE` env var, `scope:` manifest field, and a wizard pre-flight question) lets teams install a shared base configuration at `~/.claude/` and layer per-repo overrides on top — every agent already merges user-level with project-level config at read time. User-scope manifests live at `~/.config/octopus/.octopus.yml` following XDG; secrets go to `~/.config/octopus/.env.octopus` with `chmod 600`. Fields that don't make sense at user scope (`mcp`, `workflow`, `reviewers`, `githubAction`, `knowledge`) warn and are ignored; `.gitignore` updates and CI scaffolds are skipped.

🎨 The setup wizard was reorganized from 12 sequential steps into 5 grouped steps (Basics, What the AI knows and does, Integrations, Team workflow, Advanced Claude settings) with sub-question headers inside each group. A new pre-flight Quick/Full mode lets users opt for a 3-question fast path or walk the full flow. Reconfigure mode suppresses long descriptions and hints unless `OCTOPUS_WIZARD_VERBOSE=1`. The Advanced step is skipped entirely when Claude is not in the agent list.

📝 Eight new specs document the delivery: worktree-isolation, auto-mode, memory-dream, sandbox, output-styles, github-action, batch-skill, install-scopes. Roadmap reconciled with RM-011 through RM-018 in Completed.

## [1.0.0] - 2026-04-18

Marks the first stable release, consolidating RM-005 through RM-009 in a single delivery.

✨ The global CLI installer now verifies detached GPG signatures alongside the existing SHA256 check — configurable via `OCTOPUS_GPG_KEYRING`, `OCTOPUS_GPG_IMPORT_KEY`, `OCTOPUS_REQUIRE_SIGNATURE`, and `OCTOPUS_SKIP_SIGNATURE`, closing the remaining supply-chain gap on compromised mirrors. Installer hardening continues with new `--bin-dir` / `--cache-root` flags, `OCTOPUS_INSTALL_ENDPOINT` support for `file://` mirrors, and real SHA256 capture in `metadata.json`.

✨ Setup UX was unified across `install.sh`, the interactive wizard, and `setup.sh`. A new `cli/lib/ui.sh` module provides shared vocabulary that groups per-agent delivery under a single step line. Every wizard prompt now dispatches to the active TUI backend (fzf / whiptail / dialog / bash), and each of the eleven wizard steps gained a contextual explanation plus per-item hints.

📝 Role templates can now declare a `tools:` frontmatter field that is preserved for Claude Code and stripped for every other target. Language rules specs were promoted to Implemented alongside the behavioral detection rule and the project-override mechanism.

⚠️ BREAKING CHANGE: submodule mode is no longer supported. `cli/lib/update.sh`, `commands/update.md`, `tests/test_update.sh`, the submodule branch in `setup.sh` PROJECT_ROOT resolution, `OCTOPUS_CLI_REL`, and every submodule/legacy-shim reference across README, commands, and feature docs were removed. Existing submodule installs must switch to the global CLI (`install.sh`) and re-run `octopus setup`; the manifest is preserved. RM-010 (`octopus migrate` helper) was rejected as a consequence.

## [0.16.1] - 2026-04-06
Fixed a syntax error in the _select_one bash fallback function that was causing issues in the setup process. 🐛

## [0.16.0] - 2026-04-06
Added an interactive TUI setup wizard (`octopus setup`) that guides users through configuring `.octopus.yml` with multi-backend support (fzf/whiptail/dialog/bash) and full Windows/Git Bash compatibility. ✨

## [0.15.10] - 2026-04-05
Fixed the CLI setup for PROJECT_ROOT and added interactive scaffolding features. 🐛

## [0.15.9] - 2026-04-05
Fixed the CLI setup command by adding the missing setup command to cli/octopus.sh 🐛

## [0.15.8] - 2026-04-05
Added contents: write permission for GitHub release upload in CI workflow. 🐛

## [0.15.7] - 2026-04-05
Fixed a CI issue where the tar archive was causing self-modification errors by writing it to /tmp instead. 🐛

## [0.15.6] - 2026-04-05
🐛 Replaced softprops action with gh CLI and upgraded checkout to v6 in CI workflows.

## [0.15.5] - 2026-04-05
🔁 Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` on the release job so all JavaScript actions (including `actions/checkout@v4`) run under Node.js 24. The `v4.x` line bundles Node.js 20 internally regardless of the pinned version tag, causing a deprecation warning that surfaced as a runtime failure on the updated GitHub runners.