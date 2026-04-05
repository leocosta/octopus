# Feature Lifecycle

A complete documentation lifecycle system that combines a decision framework skill, document bootstrap commands, a documentation-focused role, and reusable templates.

## Decision matrix

| Factors | What to create |
|---|---|
| All factors low (single team, low uncertainty, reversible, < 1 week) | Lightweight Spec |
| Any factor high | Detailed Spec via `/octopus:doc-spec` |
| 2+ factors high | RFC first via `/octopus:doc-rfc`, then Spec after approval |
| Any architectural decision during work | ADR via `/octopus:doc-adr` |

## Available commands

- `/octopus:doc-rfc` — create RFC from template (`docs/rfcs/YYYY-MM-DD-<slug>.md`)
- `/octopus:doc-spec` — create Spec from template (`docs/specs/<slug>.md`)
- `/octopus:doc-adr` — create numbered ADR from template (`docs/adrs/NNN-<slug>.md`)

## Templates

- `templates/rfc.md`
- `templates/spec.md`
- `templates/adr.md`
- `templates/impl-prompt.md`

## Skill integration

- `feature-lifecycle` orchestrates when each artifact is needed
- `adr` provides ADR format and decision-record guidance
- `continuous-learning` captures post-implementation knowledge in `knowledge/<domain>/`

---

## Using the `tech-writer` role

The `tech-writer` role is most effective when used as a documentation-only executor with a bounded artifact, explicit evidence sources, and a clear output path.

### Recommended `.octopus.yml`

```yaml
agents:
  - claude

roles:
  - tech-writer

workflow: true
knowledge: true
```

### Pre-flight checklist

Before asking Claude to use `tech-writer`:

- Confirm the generated agent exists: `ls .claude/agents/tech-writer.md`
- Confirm the documentation commands exist: `ls .claude/commands/octopus:doc-*.md`
- Confirm the project memory exists when expected: `ls knowledge/INDEX.md`
- Confirm the target docs folders exist or can be created: `docs/specs/`, `docs/rfcs/`, `docs/adrs/`, `docs/research/`
- Decide the artifact before writing: RFC, Spec, ADR, knowledge update, changelog entry, or documentation audit
- Decide the audience: implementer, reviewer, operator, stakeholder, or future maintainer

### What to put in the first Claude message

```text
Use the `tech-writer` agent.

Audience: implementers and reviewers.
Goal: create or update a spec for the retry behavior of webhook delivery.
Output: docs/specs/webhook-retries.md
Sources of truth:
- knowledge/INDEX.md
- docs/roadmap.md
- docs/adrs/
- current webhook code
- existing tests

Constraints:
- do not modify application code
- mark inferred statements explicitly
- if the implementation differs from the current spec, add a deviation note
- if a meaningful technical decision appears, create or update an ADR
- if a reusable lesson is confirmed, update the relevant knowledge module
```

### End-to-end examples

**Pre-implementation spec work:**
```bash
# 1. Research the problem
/octopus:doc-research webhook-retries

# 2. Bootstrap the spec
/octopus:doc-spec webhook-retries

# 3. Delegate to tech-writer
Use the `tech-writer` agent.
Turn `docs/specs/webhook-retries.md` into an implementation-ready spec.
...
```

**Post-implementation reconciliation:**
```text
Use the `tech-writer` agent.
Reconcile the shipped webhook retry behavior with the existing docs.
Compare the current code, tests, PR diff, and `docs/specs/webhook-retries.md`.
Update the spec to match reality.
...
```

**Release changelog support:**
```text
Use the `tech-writer` agent.
Update `CHANGELOG.md` for the webhook retry rollout.
Ground the entry in shipped behavior, user-facing impact, operational impact,
and any migration or rollout notes.
```

### Troubleshooting

- **Generic prose**: tighten the prompt around artifact path, audience, and evidence sources.
- **Summarizes intent instead of reality**: explicitly tell it to prioritize current code and tests over conversational context.
- **Misses a decision trail**: point it at `docs/adrs/`, related PRs, and the roadmap item before asking for the update.
- **Starts editing code**: restate the constraint `do not modify application code`.
- **Output too broad**: split into separate passes — one for spec/RFC/ADR, another for changelog or knowledge capture.
