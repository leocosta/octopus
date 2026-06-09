# Spec: Copilot Command Parity

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-06-09 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | [RM-156](../roadmap.md) (Cluster 27) |

## Problem Statement

Octopus workflow commands (`/octopus:pr-open`, `/octopus:pr-review`,
`/octopus:release`, …) are authored once in `commands/*.md` and delivered as native
slash commands only to agents whose manifest declares `native_commands: true`
(Claude → `.claude/commands/`, OpenCode → `.opencode/commands/`). The GitHub Copilot
manifest (`agents/copilot/manifest.yml`) is `native_commands: false`, so those
commands never reach Copilot — a teammate using Copilot sees no `/pr-open`. The only
command surface Copilot gets today is the plain-text list of **user-defined**
`.octopus.yml` commands appended to `.github/copilot-instructions.md` by
`append_commands_section` (setup.sh) — the workflow commands are absent entirely.

Copilot *does* support repo-scoped slash commands as **prompt files**
(`.github/prompts/<name>.prompt.md`, invoked as `/<name>` in chat), but only in the
IDE clients (VS Code, Visual Studio, JetBrains). The Copilot **CLI** has no
equivalent (feature request github/copilot-cli#618, closed without implementation),
so a prompt file is inert in the terminal.

This is a fleet parity gap: the same standards-bearing workflows should be one
keystroke away regardless of which assistant a teammate runs.

## Goals

- IDE Copilot users (VS Code / Visual Studio / JetBrains) can invoke each Octopus
  workflow command as a `/octopus-<name>` slash command, generated from the single
  source `commands/*.md`.
- Terminal Copilot users get a discoverable **text/CLI fallback**: the workflow
  commands listed in `.github/copilot-instructions.md` as their `octopus <name>` CLI
  equivalents (since prompt files do nothing in the CLI).
- The mechanism is **manifest-driven and capability-gated** — keyed on a capability
  flag, not on the agent name — so any agent exposing the same prompt-file surface
  reuses it with one manifest line.
- Zero regression for existing native-command agents (Claude, OpenCode) and for the
  existing user-command text listing.
- `octopus setup` re-run is idempotent and prunes stale generated prompt files (no
  orphans), consistent with the existing command-pruning behavior.

## Non-Goals

- Native slash commands in the Copilot **CLI** — blocked upstream
  (github/copilot-cli#618); the CLI fallback is text-only by design.
- Changing how user-defined `.octopus.yml` commands are delivered.
- Porting commands to agents beyond Copilot in this spec, though the design must
  generalize (capability flag) so JetBrains/Visual Studio and future agents reuse it.
- Rendering skills, hooks, or agents as prompt files — commands only.

## Design

### Overview

Add a new delivery capability to the manifest schema — `native_prompt_files` — and a
matching `delivery.commands` rendering **method** (`prompt_files`). When an agent
declares it, `setup.sh` transforms each `commands/*.md` into a Copilot prompt file
under the manifest's command target (`.github/prompts/`). For agents without native
commands *and* without prompt files, the existing text fallback is extended to also
list the workflow commands as CLI invocations.

Delivery decision per agent capability:

| Capability | Workflow-command surface |
|---|---|
| `native_commands: true` | native command files (current: Claude, OpenCode) — unchanged |
| `native_prompt_files: true` | `prompt_files` render → `.github/prompts/octopus-<name>.prompt.md` (Copilot IDE) |
| neither | text/CLI fallback in the concatenated instructions file |

### Detailed Design

**Manifest (`agents/copilot/manifest.yml`).** Add the capability and a commands
delivery block:

```yaml
capabilities:
  native_commands: false
  native_prompt_files: true        # new
delivery:
  commands:                        # new
    method: prompt_files
    target: .github/prompts/
    prefix: octopus-               # filename prefix to avoid user-prompt collisions
```

**Renderer (`setup.sh`).** A new function, e.g. `render_prompt_file_commands()`,
invoked from the delivery dispatch when `method == prompt_files`. For each
`commands/<name>.md`:

1. Strip the Octopus frontmatter keys `name:` and `cli:` (the same two lines the
   `.claude`/`.opencode` mirrors already drop).
2. Emit Copilot prompt-file frontmatter — `description:` (sourced from the command's
   existing `description:`) and `mode: agent`. Workflow commands take actions
   (commit, push, open PR, release) and need tools/terminal, so `agent` is the
   correct mode; `ask` (chat-only) does not fit. Other keys (`tools`, `model`) are
   out of scope for v1.
3. Translate the argument placeholder: Octopus/Claude `$ARGUMENTS` → Copilot
   `${input}`. **v1 handles the free `$ARGUMENTS` form only** — it covers the common
   case (most commands take an unstructured argument). Named/richer argument forms
   are a documented follow-up, since they need per-command review.
4. Write to `<target>/<prefix><name>.prompt.md`.
5. Track generated files so a later `setup` run prunes ones whose source was removed
   (mirror the existing stale-command pruning).

**CLI fallback (`append_commands_section` or a sibling).** Today it lists only
`.octopus.yml` user commands. Extend it (when the agent has neither native commands
nor prompt files — or unconditionally for the instructions file) to also enumerate
the workflow commands as `- **<name>** — <description>: \`octopus <name>\``, so
terminal Copilot users can discover and run them.

**Parsing.** The manifest parser in `setup.sh` already reads `native_commands` and
`commands_method`/`commands_target`/`commands_prefix` (`MANIFEST_DELIVERY_COMMANDS_*`).
Add `native_prompt_files` to the capability switch and route `method: prompt_files`
to the new renderer; existing `symlink`/copy methods are untouched.

### Migration / Backward Compatibility

Purely additive. No existing manifest changes for Claude/OpenCode; their native
command delivery is unchanged. The only behavioral change for Copilot is *new*
generated files under `.github/prompts/` plus extra lines in
`.github/copilot-instructions.md`.

**Decision: the generated prompt files are git-ignored** (added to the Copilot
manifest's `gitignore_extra`). They are treated as a local install artifact —
regenerated by `octopus setup` from the single source `commands/*.md`, like the
`.claude`/`.opencode` command mirrors — so they never appear in PR diffs and cannot
drift in version control. Trade-off: a teammate who has not run `octopus setup` will
not have the `/octopus-*` prompt files; this is consistent with how every other
generated agent surface already works (running `setup` is the contract).

## Implementation Plan

1. **Manifest schema + parser** — `setup.sh`: add `native_prompt_files` to the
   capability parse/reset block (`MANIFEST_CAP_*`) and ensure `commands` delivery is
   read even when `native_commands: false`.
2. **Renderer** — `setup.sh`: `_deliver_prompt_file()` (drop source frontmatter +
   emit `description:` + `mode: agent` + `$ARGUMENTS`→`${input}`) plus a rendering
   loop in `deliver_commands`' non-native branch, gated on
   `MANIFEST_CAP_PROMPT_FILES`, with prefixed output and stale-file pruning.
3. **CLI fallback** — *already exists.* `deliver_commands`' non-native branch already
   appends a `# Octopus Commands` section to `.github/copilot-instructions.md`
   listing each workflow command as `Run: octopus <name>`. The prompt-file rendering
   is added *alongside* it (before that branch's instructions-file guard), so
   terminal Copilot keeps the text fallback and IDE Copilot gains slash commands. No
   change needed here.
4. **Copilot manifest** — `agents/copilot/manifest.yml`: add `native_prompt_files:
   true` and the `delivery.commands` block; add `.github/prompts/` to
   `gitignore_extra`. (No separate cleanup list exists — `deliver_commands` prunes
   stale `octopus-*.prompt.md` on each run, matching the native-command prune.)
5. **ADR** — record `docs/adr/011-capability-gated-delivery.md`: delivery extensions
   are gated on a manifest capability, never on the agent name. (Authored alongside
   this spec.)
6. **Tests** — extend the agent-generation tests (see Testing Strategy).
7. **Docs** — note the Copilot prompt-file surface in `agents/copilot/header.md`
   (currently states "Slash commands `/octopus:*` do not exist in Copilot"); update
   the public docs/site command-availability matrix if one exists.

## Context for Agents

**Knowledge modules**: [architecture, setup/manifest delivery]
**Implementing roles**: [backend-developer]
**Related ADRs**: [ADR-011](../adr/011-capability-gated-delivery.md) — delivery
extensions are capability-gated, not agent-name-gated (recorded with this spec)
**Skills needed**: [doc-design, implement, tdd, audit-config]
**Bundle**: N/A (no new skill; extends the setup/manifest engine)

**Constraints**:
- Pure bash in `setup.sh`; no new external dependencies.
- Single source of truth stays `commands/*.md` — no hand-authored prompt files.
- Capability-gated, not agent-name-gated (manifest-driven altitude).
- Backward compatible: Claude/OpenCode native delivery and user-command listing
  unchanged.
- Idempotent setup with stale-file pruning.

## Testing Strategy

- **Renderer unit/structural test** — given a fixture `commands/<name>.md`, the
  `prompt_files` method produces `.github/prompts/octopus-<name>.prompt.md` with: no
  `name:`/`cli:` lines, a `description:` carried over, and `$ARGUMENTS` rewritten to
  `${input}`.
- **Capability routing** — an agent with `native_commands: false` +
  `native_prompt_files: true` triggers the prompt-file renderer; one with
  `native_commands: true` does not (no `.github/prompts/` output).
- **CLI fallback** — `.github/copilot-instructions.md` lists the workflow commands as
  `octopus <name>` invocations.
- **Pruning/idempotency** — removing a source command and re-running setup deletes its
  generated prompt file; re-running with no changes is a no-op.
- **Regression** — Claude/OpenCode command mirrors and the existing
  `append_commands_section` user-command listing are unaffected
  (`test_concatenate_agent`, command-related tests stay green).

## Risks

- **Copilot prompt-file frontmatter drift** — the schema is owned by GitHub/VS Code
  and may evolve; keep the emitted frontmatter minimal (`description`, `mode`) to
  reduce breakage surface.
- **Filename collisions** with user-authored prompt files — mitigated by the
  `octopus-` prefix; document it.
- **IDE-only value** — terminal Copilot users still cannot use slash commands
  (upstream limitation); the CLI fallback must be clear so this isn't perceived as a
  bug. State it in `agents/copilot/header.md`.
- **Argument-placeholder fidelity** — `$ARGUMENTS` → `${input}` is a simple case;
  commands relying on richer argument handling may need per-command review.

## Changelog

- **2026-06-09** — Initial draft (graduated from RM-156 / Cluster 27).
- **2026-06-09** — Design session completed: prompt files git-ignored (local install
  artifact); `mode: agent`; v1 argument translation is `$ARGUMENTS`→`${input}` only;
  ADR-011 recorded for capability-gated delivery.
