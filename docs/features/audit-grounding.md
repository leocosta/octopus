# Audit-Grounding

Signal-only audit that confronts the working diff against the repo's
living source of truth — `CONTEXT.md`, `docs/adr/`, and the knowledge
base — to surface the two semantic hallucinations a formatter and a
type checker can never catch: conventions an agent invented without
agreement, and domain facts it asserted without support.

## When to use

When an AI agent (or a hurried human) might introduce a naming, folder,
or field convention nobody agreed on, or write a domain claim that
contradicts the decisions of record. The syntactic failures —
unformatted code, type errors, leaked secrets — are already blocked by
the `guardrails` bundle; `audit-grounding` covers the semantic layer
that only a reader holding the source of truth can judge.

It is **signal-only**: it never blocks a commit, task, or merge. It
reports `warn`/`info` findings and leaves the call to a human, because
the verdict comes from a probabilistic reading of documents.

## The two layers, together

A complete local guardrail against code-assistant drift is two bundles,
no CI required:

- **Syntactic, blocking — the `guardrails` bundle.** Pre-commit
  (git-level) + loop-level hooks (`auto-format`, `typecheck`,
  `block-no-verify`, `detect-secrets`) + IDE configs. Catches every
  commit, human or agent, and blocks. Requires `hooks: true`.
- **Semantic, signal-only — `audit-grounding` in the `quality`
  bundle.** Fires at the end of every agent task via the
  `grounding-check` Stop hook, which queues a grounding review in
  `.octopus/proposals/` for `/octopus:review-proposals`.

## Findings

- **`invented-convention`** — a naming, folder, field, or structural
  pattern the diff introduces that is not grounded in `CONTEXT.md` or
  an ADR.
- **`unsupported-domain-fact`** — a domain or business claim in the diff
  that contradicts or is absent from the decisions of record.

When `CONTEXT.md` is absent the audit degrades to `docs/adr/` and the
knowledge base and reports the partial grounding as an `info` note.

## Enable

Add the `quality` bundle to `.octopus.yml` (it lists `audit-grounding`):

```yaml
bundles:
  - quality
  - guardrails
hooks: true
```

`guardrails` closes the syntactic layer; `quality` brings
`audit-grounding`; `hooks: true` activates the `grounding-check` Stop
hook trigger. The trigger is deterministic — it fires on every task end
with a diff — while the grounding judgment stays signal-only.
