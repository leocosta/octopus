# ADR-011: Delivery extensions are capability-gated, not agent-name-gated

## Status

Accepted — 2026-06-09

## Context

Octopus delivers its content (rules, skills, commands, hooks, MCP, …) to each AI
assistant through a per-agent manifest (`agents/<agent>/manifest.yml`) that declares
`capabilities:` (booleans like `native_commands`, `native_skills`, `native_mcp`) and
a `delivery:` map of methods/targets. `setup.sh` reads those and materialises the
right files for each agent. RM-156 (Copilot command parity, see
[spec](../specs/copilot-command-parity.md)) adds a *new* way to deliver workflow
commands — GitHub Copilot prompt files (`.github/prompts/*.prompt.md`) — which only
some agents/clients support. The question: how should the engine decide when to emit
prompt files (and, by extension, any future delivery format)?

## Sources

- `docs/specs/copilot-command-parity.md` — RM-156 design
- `agents/*/manifest.yml` — existing `capabilities` + `delivery` schema
- `setup.sh` — `MANIFEST_CAP_*` / `MANIFEST_DELIVERY_*` parsing and dispatch
- `agents/copilot/header.md` — current "no slash commands in Copilot" note

## Decision

New delivery behaviors are gated on a **manifest capability flag**, never on the
agent's name. RM-156 adds a `native_prompt_files` capability and a `prompt_files`
delivery method; `setup.sh` routes on the capability/method, so any agent that sets
`native_prompt_files: true` (Copilot today; JetBrains/Visual Studio later) reuses the
same renderer with one manifest line. `setup.sh` must contain no `if agent ==
"copilot"` branches for delivery.

## Alternatives Considered

### Branch on the agent name in `setup.sh`

- **Pros:** fastest to write for a single agent; no schema change.
- **Cons:** every new agent that shares the surface needs another code branch; the
  engine accumulates a per-agent ladder; contradicts the existing manifest-driven
  design where `setup.sh` is agent-agnostic and the manifest is the source of truth.

### Infer capability from the agent's other fields (e.g. presence of a `commands` target)

- **Pros:** no new capability key.
- **Cons:** implicit and ambiguous — a `commands` target already means native command
  files for Claude/OpenCode; overloading it to also mean "prompt files" couples two
  unrelated behaviors and makes the manifest unreadable.

## Consequences

### Positive

- Adding prompt-file support to a new agent is a one-line manifest change, no engine
  edit.
- `setup.sh` stays agent-agnostic; the manifest remains the single source of truth
  for what each agent can receive.
- Establishes the rule for all future delivery formats: add a capability + method,
  not a name branch.

### Negative

- Slightly more manifest schema surface (one more capability key) and a parse/reset
  line in `setup.sh`.

### Risks

- Capability sprawl if every minor variation gets its own flag; mitigate by reserving
  capabilities for genuinely distinct delivery surfaces, not cosmetic differences.
