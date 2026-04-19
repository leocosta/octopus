# Spec: Sandbox

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Status** | Implemented |
| **Roadmap** | RM-014 |
| **Research** | [boris-cherny-tips](../research/2026-03-30-boris-cherny-tips.md) (Part 3) |

## Problem

Destructive shell commands (rm -rf, DROP TABLE, npm uninstall) can cause data loss when executed unsandboxed. Claude Code ships a sandbox facility that runs tool calls in an isolated process tree with limited filesystem access, but it is opt-in and not exposed by Octopus.

## Design

New manifest key `sandbox: true`. Parsed into `$OCTOPUS_SANDBOX`, delivered via `deliver_boris_settings` into `.claude/settings.json` as boolean `"sandbox"`.

Once CC reads the key, every subsequent tool call is wrapped in its sandbox. Paths outside the project root are read-only; network calls require explicit opt-in; destructive syscalls are intercepted.

Pairs well with `permissionMode: auto` (RM-012): the classifier decides what is safe, the sandbox catches the classifier's mistakes.

## Out of scope

- Fine-grained sandbox policies (allowed paths, network egress). CC does not expose these via settings.json today.
- A poly-fill for non-Claude agents (sandbox is a CC feature).
