---
name: consigliere-lens
description: >
  Make the generic knowledge engines (hygiene/synthesize/briefing) read like
  the consigliere over the private workspace — political risk surfaced, per-
  node playbook heuristics applied, the 'thinks like you' voice. A wrapper:
  engines stay generic, the octopus lens helper surfaces grounded material,
  the consigliere role (opus) frames it. Read-only.
triggers:
  paths: []
  keywords: ["consigliere", "lens", "political risk", "playbook", "manager briefing"]
  tools: []
---

# /octopus:consigliere-lens

## Purpose

The engines (`hygiene`, `synthesize`, `briefing`) are generic and read like flat
reports on any root. Run against the consigliere workspace, their findings
should read like the **consigliere**: the political read others miss,
the heuristics you already hold, your own voice. This skill applies that lens by
reusing the engines — it does not fork them.

## Invocation

```
/octopus:consigliere-lens [--engine hygiene|synthesize|briefing] [--daily|--weekly]
```

- `--engine` — which engine to run against the consigliere root (default `briefing`).
- `--daily` / `--weekly` — passed through to `briefing` (default `--daily`).

## Flow

1. Confirm the lens applies: `octopus lens profile consigliere` must return `consigliere`. If empty, stop — no workspace is configured.
2. Run the chosen engine **read-only** against the workspace: `octopus <engine> --root consigliere` (never `--fix`).
3. For each finding's node, pull the grounded lens material: `octopus lens context <node>` → the sibling `playbook|`, the `risk|` lines (`## Political risk`), the `blocker|` lines (`## Blockers`).
4. Reframe the findings through the consigliere voice (see below), weaving in the political risk and applying the playbook heuristics (push the ones that apply, pull the ones that don't).

## Voice

The lens speaks as the **`consigliere` role (`model: opus`)** — not the engines' cheap-tier narration. Political nuance and "thinks like you" judgment warrant the stronger model. Invoke it via `octopus ask --role consigliere` (or the assistant's equivalent) so the briefing reads in the manager's own register.

## Grounding

Every line must cite its source — `(src: <node>)` plus the specific `playbook|`/`risk|`/`blocker|` line it draws from. Surface no political read that the workspace does not support; the lens sharpens what is recorded, it does not invent.

## Write-guard

The lens is **read-only**. It composes engine runs **without `--fix`** and never writes the workspace. The consigliere root carries the workspace write-policy; honor it — managerial data is never mutated by the lens.
