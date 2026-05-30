---
name: enforce-precommit
description: >
  Install and maintain a pre-commit framework configuration aligned with
  the project's Octopus rules. Closes the git-level enforcement gap that
  Octopus loop-level hooks (auto-format, typecheck, console-log-warn,
  block-no-verify) cannot cover for Copilot edits or direct human commits.
  Detects project stack(s) via file extensions, infers checks from
  rules/common/*, and writes/updates `.pre-commit-config.yaml` (default)
  or `lefthook.yml` / `.husky/` (documented alternatives) idempotently.
  Respects existing config — merges hook entries by id rather than
  overwriting. Project-level extension via enforce-precommit.local.md.
  Pairs with the guardrails bundle and the qualityWorkflow CI template.
triggers:
  paths: [".pre-commit-config.yaml", "lefthook.yml", ".husky/**", ".octopus.yml"]
  keywords: ["enforce precommit", "install precommit", "precommit drift", "lefthook setup", "husky setup", "guardrails precommit"]
---

# Pre-commit Enforcement

## Overview

Octopus's `hooks/hooks.json` runs deterministic checks inside the Claude
Code tool loop — `auto-format`, `typecheck`, `console-log-warn`,
`block-no-verify`, `detect-secrets`, `destructive-guard`, `format-check`,
`git-push-reminder`, `mark-stale-translation`. That covers Claude Code's
edit path completely.

Two paths are not covered:

1. **Copilot edits** (chat or agent mode) — Copilot does not trigger
   Claude Code hooks.
2. **Direct human edits** committed without going through Claude Code.

A pre-commit framework rooted in the git lifecycle closes both. This
skill installs and maintains that configuration alongside Octopus, with
the same enforced set as the loop-level hooks.

## When to Engage

Engage when:

- The user adds `guardrails` to `.octopus.yml` for the first time.
- A new stack is added to the repo (skill re-runs and extends).
- The pre-commit framework configuration drifts from the rule set
  declared in `rules/common/*`.
- A team adopts Copilot alongside Claude Code and asks for "the same
  enforcement to apply to both".

Do not engage when:

- The repo explicitly opts out via a `enforce-precommit.local.md` note
  saying "managed externally" (e.g., monorepo with centralized
  pre-commit at the root).
- The user only wants Claude Code coverage and does not consume
  Copilot — loop-level hooks already suffice.

## Protocol

### Step 1 — Detect stacks

Walk the repo (excluding `node_modules`, `dist`, `build`, `target`,
`.git`, vendored paths) and count files by extension. A stack is
"active" if it has more than 10 files or contains a canonical manifest
(`package.json`, `pyproject.toml`, `*.csproj`, `go.mod`, `Cargo.toml`,
`Gemfile`).

Default stack-to-toolchain mapping:

| Stack | Formatter | Linter | Manifest |
|---|---|---|---|
| TypeScript / JavaScript | biome OR prettier | biome OR eslint | `package.json` |
| Python | ruff format | ruff check | `pyproject.toml` |
| C# / .NET | dotnet format | dotnet build / analyzers | `*.csproj` |
| Go | gofmt | golangci-lint | `go.mod` |
| Rust | rustfmt | clippy | `Cargo.toml` |

Existing project choice (e.g., a `biome.json` overrides "prettier OR
biome") always wins. Never replace a formatter already chosen.

### Step 2 — Choose framework

Default: **`pre-commit.com`** (polyglot, mature, Python-installed,
broadest plugin coverage). Override via manifest flag
`enforce_precommit_framework: lefthook | husky | pre-commit` in
`.octopus.yml` or via `enforce-precommit.local.md`.

If the repo already has one of the three frameworks installed
(`.pre-commit-config.yaml`, `lefthook.yml`, `.husky/`), respect it —
extend rather than replace.

### Step 2.5 — Resolve the workspace template (RM-095, D5)

Before generating, resolve the config source with this precedence
(highest wins):

1. **Project-local** — an existing framework config in the repo
   (`.pre-commit-config.yaml`, `lefthook.yml`, `.husky/`) or
   `enforce-precommit.local.md` directives. Intentional repo choices;
   extended, never replaced.
2. **Workspace template** — if the manifest sets `workspace:` and
   `<workspace>/templates/precommit/<stack>.*` exists (e.g.
   `dotnet.pre-commit-config.yaml`, `node.husky/`), use it as the
   **canonical base**, taking precedence over the generated default below.
   This lets a fleet manager curate one git-level standard (see
   `fleet-bootstrap`).
3. **Generated default** — Step 3's stack-inferred config; the fallback
   when the workspace provides no template.

When a workspace template is used, Step 3 merges the repo's existing hooks
on top of it (by `id:`) rather than the built-in baseline.

### Step 3 — Generate / merge config

For `pre-commit.com`, write `.pre-commit-config.yaml` with one repo
block per detected stack plus the universal blocks:

- `pre-commit-hooks` (check-yaml, end-of-file-fixer, trailing-whitespace,
  check-merge-conflict, check-added-large-files)
- `conventional-pre-commit` (commit-msg stage; enforces Conventional
  Commits per `rules/common/commit-conventions.md` if present)
- `detect-secrets` (parity with Octopus `detect-secrets` hook)

For each active stack, add the canonical formatter + linter hook.
Merge semantics:

- If a hook with the same `id:` already exists in the user's config,
  leave it untouched and log "skipped (already configured)".
- Append new hooks rather than reorder existing ones.
- Never delete a user-added hook.

### Step 4 — Install and verify

Run:

```bash
pre-commit install --hook-type pre-commit --hook-type commit-msg
pre-commit run --all-files
```

Report results. If `pre-commit run` finds violations, list them but
do not auto-fix beyond what the formatter does — let the user review.

### Step 5 — Document local overrides

If `enforce-precommit.local.md` exists, surface its contents in the
output so the user remembers what was customized. Project-level
overrides live there (e.g., "skip ruff on `legacy/` directory until
refactor PR-432 lands").

## Output

Print a severity-tiered summary:

```
[ok]   Detected stacks: TypeScript, Python
[ok]   Framework: pre-commit.com (default)
[ok]   Wrote .pre-commit-config.yaml (3 new hooks, 2 preserved)
[ok]   Installed git hooks: pre-commit, commit-msg
[warn] 4 files need formatting — run `pre-commit run --all-files`
[info] Local overrides loaded from enforce-precommit.local.md
```

Exit non-zero only if installation itself failed; formatter findings
exit zero (informational).

## Anti-Patterns

- Overwriting a user's existing `.pre-commit-config.yaml` instead of
  merging.
- Picking a different formatter than what the project already uses
  (e.g., installing prettier when `biome.json` is present).
- Adding language-specific hooks for stacks that are not actually
  active (one stray `.py` file in `scripts/` does not justify a Python
  pipeline).
- Running `pre-commit autoupdate` automatically — version drift is the
  user's call, not the skill's.
- Removing a hook the user added manually because it is not in the
  skill's default set.

## Integration with Other Skills

- **`guardrails` bundle** — this skill is loaded by the guardrails
  bundle alongside `enforce-ide`.
- **`enforce-ide`** — sibling; both targeted by the same RFC. IDE
  configs reinforce visually what pre-commit enforces at git level.
- **`audit-config`** — periodically reviews whether the generated
  pre-commit config has drifted from `rules/common/*`.
- **Loop-level hooks** (`auto-format`, `typecheck`, etc.) — same
  checks, different surface. Pre-commit catches what the loop misses
  (Copilot, direct human edits).
- **`templates/github-actions/quality.yml`** — CI mirror of the same
  rule set. The three layers (loop / pre-commit / CI) share a single
  source of truth via `rules/common/*`.

## References

- RFC: `docs/rfcs/2026-05-20-team-workspace-guardrails.md`
- Related plan: `/home/leonardo/.claude/plans/por-que-os-agentes-goofy-gosling.md`
- `pre-commit.com`: https://pre-commit.com/
- `lefthook`: https://github.com/evilmartians/lefthook
- `conventional-pre-commit`: https://github.com/compilerla/conventional-pre-commit
