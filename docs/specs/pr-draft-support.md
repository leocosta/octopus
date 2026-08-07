# Spec: Draft PR support

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-08-07 |
| **Status** | Draft |
| **Roadmap** | RM-182 |

## Problem

`/octopus:pr-open` always creates a ready-for-review PR. There is no way to
open work-in-progress for CI feedback, for an early architectural read, or to
stack a branch, without leaving Octopus and running `gh pr create --draft` by
hand — which forfeits the agent-written title and body that is the whole point
of the command.

The gap has a second half: once a draft exists, nothing in Octopus promotes it.
`pr-review` assigns human reviewers to a PR that is still a draft, which
silently produces a review request nobody can act on.

## Goals

- `/octopus:pr-open <branch> --draft` opens the PR as a draft, keeping the
  agent-written title and body unchanged.
- A first-class `pr-ready` command promotes a draft to ready for review.
- `dev-flow` covers both, so the guided workflow has no hole between
  `continue` and `review`.
- Every new surface is registered, documented in both languages, and tested.

## Non-Goals

- **Draft as a default.** No `.octopus.yml` key, no `--ready` inverse flag.
  Draft is opt-in per invocation. A repo-wide default can be added later if a
  team asks for it; nothing here forecloses that.
- **Heuristic auto-draft.** The agent will not infer draft-ness from `wip/`
  branch prefixes, `wip:` commits, or failing tests. Opening a PR is a
  visible, outward-facing act; guessing its state is worse than being told.
- **Auto-promotion from `pr-review`.** Requesting a review will not silently
  call `gh pr ready`; promotion stays an explicit act. `pr-review` is not
  touched by this spec at all.
- **Fixing the stale `pr-open` docs page** (see Known drift, below).

## Design

### Overview

Two independent changes that compose:

1. `pr-open` gains a pass-through boolean flag. The CLI keeps its existing
   contract — the agent writes the prose, the CLI runs the mechanics — and
   `--draft` is pure mechanics, so it belongs entirely in `cli/lib/pr-open.sh`
   with the command file only responsible for forwarding it.
2. `pr-ready` is a new command in its own right, symmetric with `pr-open` /
   `pr-review` / `pr-comments` / `pr-merge`, discoverable in `octopus help`
   and in the commands index.

### `cli/lib/pr-open.sh`

Add a boolean to the argument parser:

```bash
--draft) DRAFT=1; shift ;;
```

The `gh` invocation becomes an array so the absent flag contributes no empty
argument:

```bash
GH_ARGS=(--base "$TARGET" --title "$PR_TITLE" --body-file "$BODY_FILE")
[[ -n "$DRAFT" ]] && GH_ARGS+=(--draft)
gh pr create "${GH_ARGS[@]}"
```

The script already echoes `OCTOPUS_PR=<number>`; it additionally echoes
`OCTOPUS_PR_DRAFT=true` when the flag was set, so the agent knows which next
step to suggest without re-querying GitHub.

`gh pr create --draft` fails on private repositories outside a paid GitHub
plan. When the flag was requested and `gh` exits non-zero, print one line of
guidance — drafts require a paid plan on private repos; re-run without
`--draft` — and propagate the failure. No silent fallback to a non-draft PR:
the PR state is outward-facing and must match what was asked for.

### `commands/pr-open.md`

Step 1 currently reads `$1` as the target branch. `/octopus:pr-open --draft`
would therefore treat `--draft` as a branch name. The argument rule becomes
explicit: **skip tokens beginning with `--` when resolving the target**;
`--draft` anywhere in `$ARGUMENTS` enables draft mode. Both of these forms
must work:

```
/octopus:pr-open --draft
/octopus:pr-open main --draft
```

Step 8 forwards the flag to the CLI. Step 11 (close-out) branches: for a draft
PR, suggest `/octopus:pr-ready <number>` first, then `/octopus:pr-review
<number>`; otherwise keep suggesting `pr-review` directly.

### `cli/lib/pr-ready.sh` (new)

```
Usage: octopus.sh pr-ready [<pr-number>]
```

The number is optional and falls back to the PR for the current branch
(`gh pr view --json number -q '.number'`), matching how a developer actually
invokes it right after `pr-open`.

The command reads `gh pr view <n> --json isDraft -q '.isDraft'` first. If the
PR is already ready, it prints a notice and **exits 0** — promotion is
idempotent, so re-running it (or running it inside `dev-flow`) never breaks a
chain. If it is a draft, it runs `gh pr ready <n>`, confirms, and points at
`/octopus:pr-review <n>`.

### `commands/pr-ready.md` (new)

Follows the `pr-merge.md` shape: `name`, `description`, `cli:
octopus.sh pr-ready` frontmatter and an `## Instructions` body. No `model:`
tier — the command runs mechanics, it does not author prose, so it stays on
the session model like `pr-review` and `pr-merge`.

### Registration

- One line in `cli/lib/commands.default`:
  `pr-ready|Mark a draft PR as ready for review`. This is load-bearing:
  `cli/octopus.sh` rejects any name absent from the registry, and
  `tests/test_cli_registry.sh` asserts every registered name has a backing
  `cli/lib/<name>.sh`.
- `pr-ready` appended to `cli_agents_select` in `agents/copilot/manifest.yml`.
- Slash-command delivery needs no change: `deliver_commands` iterates
  `commands/*.md`, so the new file ships to every configured agent.

### `cli/lib/dev-flow.sh`

`dev-flow continue` already forwards `"$@"` to `pr-open.sh`, so `--draft`
works there with no code change. A new `ready` action is added between
`continue` and `review`, sourcing `pr-ready.sh`, with matching lines in both
the header comment and `usage()`.

### Migration / Backward Compatibility

Fully additive. Every existing invocation — `octopus pr-open --target main
--body-file x.md`, `dev-flow continue`, the agent's step 8 — behaves exactly as
before. `OCTOPUS_PR_DRAFT` is a new output line, only emitted for drafts, so
nothing parsing `OCTOPUS_PR=` is affected.

## Implementation Plan

1. `cli/lib/pr-open.sh` — `--draft` parsing, `GH_ARGS` array, failure hint,
   `OCTOPUS_PR_DRAFT` output.
2. `cli/lib/pr-ready.sh` — new script.
3. `cli/lib/commands.default` — register `pr-ready`.
4. `commands/pr-open.md` — argument rule, step 8 forwarding, step 11
   close-out.
5. `commands/pr-ready.md` — new command file.
6. `cli/lib/dev-flow.sh` — `ready` action + usage.
7. `agents/copilot/manifest.yml` — add to `cli_agents_select`.
8. Tests: extend `tests/test_pr_open.sh`, add `tests/test_pr_ready.sh`,
   extend `tests/test_workflow_commands.sh`.
9. Docs: `docs/site/commands/pr-ready.mdx` (new), plus `pr-open.mdx`,
   `index.mdx`, `dev-flow.mdx` — each in `docs/site/` and
   `docs/site/pt-br/` — and `docs/features/workflow.md`.
10. `docs/roadmap.md` — RM-182 entry.
11. `cd site && bun run sync-content && bun run build`.

## Context for Agents

**Skills needed**: none (no new skill, therefore no bundle mapping required)
**Constraints**:

- Pure bash, no new external dependencies. `gh` and `git` only.
- The CLI never authors prose; the agent never shells out for mechanics.
- Repo content is English-only, except `docs/site/pt-br/`.
- New doc pages must exist in both `docs/site/` and `docs/site/pt-br/` —
  `site/scripts/check-docs.sh` requires a page per `commands/*.md`.

## Documentation

`docs/site/commands/pr-ready.mdx` takes `sidebar.order: 5`, tying with
`pr-review.mdx` and sorting ahead of it alphabetically. Duplicate orders
already occur throughout that directory, and the tie avoids renumbering six
downstream pages for a cosmetic gain.

## Testing Strategy

Grep-and-exit-code assertions against a stubbed `gh`, per project convention.

- `tests/test_pr_open.sh` — the `gh` stub records its arguments.
  `--draft` present → `pr create` receives `--draft`; flag absent → it does
  not. The second half is the one that matters: it catches an unconditional
  flag.
- `tests/test_pr_ready.sh` (new) — no argument and no PR on the branch prints
  usage and exits non-zero; a PR reporting `isDraft: false` exits 0 **without**
  calling `gh pr ready`; a PR reporting `isDraft: true` calls it.
- `tests/test_workflow_commands.sh` — `octopus:pr-ready.md` is delivered.

## Risks

- **Drafts are unavailable on private repos on the free plan.** Mitigated by
  the explicit failure hint rather than a fallback. Low impact: the failure is
  from `gh`, before any PR exists, so re-running without the flag is clean.
- **`--draft` colliding with the positional branch argument.** This is the one
  real correctness risk, and it lives in the command file rather than in bash.
  Mitigated by stating the skip-`--`-tokens rule explicitly and by documenting
  both invocation forms.

## Known drift (out of scope)

`docs/site/commands/pr-open.mdx` describes a Conventional-Commits title format
and a `Summary / Related Issues / How to Test / Screenshots` body. Neither
matches `commands/pr-open.md` today, which forbids the `type:` prefix and
specifies `📦 What / 💡 Why / ✅ Test plan / 🔗 References`. Correcting it here
would bury the draft change in an unrelated rewrite; it deserves its own item.

## Changelog

- **2026-08-07** — Initial draft
