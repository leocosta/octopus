# Spec: Persistent Memory + Dream Subagent

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Status** | Implemented |
| **Roadmap** | RM-013 |
| **Research** | [boris-cherny-tips](../research/2026-03-30-boris-cherny-tips.md) (tips 15 + 45) |

## Problem

Claude Code supports persistent memory that survives across sessions, but memory accretes over time — stale facts, overlapping notes, outdated deadlines. Boris's tip 15 introduces auto-memory; tip 45 proposes an "auto-dream" subagent that periodically consolidates and prunes.

Without Octopus standardization, each team configures both features ad-hoc, if at all.

## Design

Two manifest flags:

- `memory: true` — enables CC's auto-memory capture (`"autoMemory": true` in settings.json).
- `dream: true` — marks the "dream" subagent as a scheduled consolidator (`"autoDream": true` in settings.json). The subagent template ships at `agents/claude/agents/dream.md` and is delivered natively alongside other roles.

The dream subagent uses Haiku (cheap, fast) with only `Read`/`Write` tools — it cannot shell out or compromise the repo. Its full loop (overlap / contradiction / staleness detection + MEMORY.md update) is documented in the agent file.

`setup.sh` delivers the subagent file when `dream: true` is set AND Claude is in `agents:`. The actual scheduling is CC's responsibility; Octopus just declares intent.

## Out of scope

- Custom memory directories / cross-agent memory sharing.
- A non-Claude implementation (no other agent has persistent memory yet).
- Forcing specific dream run frequency (CC decides; default is daily).
