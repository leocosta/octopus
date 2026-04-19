# Changelog

All notable changes to this project will be documented in this file.

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