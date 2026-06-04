---
name: audit-verification
description: >
  Signal-only audit confronting a finished task against its run evidence: a
  completion claimed without build/test/typecheck running (unverified-
  completion-claim), and a diff referencing a file the build would reject
  (unresolved-reference). Never blocks; runs on demand via /octopus:review-
  proposals on the cheapest tier. Queued by the zero-LLM verification-check
  Stop hook.
triggers:
  keywords: ["audit verification", "verification check", "claimed done", "unverified", "did it run"]
---

# Verification Audit

## Overview

A formatter, a type checker, and a secret scanner judge **syntax**, and
`audit-grounding` judges **meaning** — but neither asks the simplest question:
*was the work actually verified?* An agent can end a task asserting "done, tests
pass" without ever running them, and can write code referencing a symbol or file
that does not exist. The compiler would catch the latter — but only if it is run.

`audit-verification` is that check. It is **signal-only** and **cheap**: the
recurring, per-task part is a pure-bash Stop hook (`hooks/stop/verification-check.sh`)
that queues a proposal only when the work looks unverified. This skill reads the
queued proposal, the diff, and the session, and emits:

- **`unverified-completion-claim`** — the session asserts done / passing / fixed,
  but the hook's run-evidence scan found no build / test / typecheck this session.
  Judge the claim against what actually ran; report the gap.
- **`unresolved-reference`** — the hook already detected, deterministically, a
  changed file importing a relative path that does not resolve on disk. Confirm
  and contextualize it; do not re-derive it.

## Cost contract

The only recurring (per-task) component is the bash hook — **it never invokes an
LLM**. This skill runs **only on demand** via `/octopus:review-proposals`, in
batch, and on the **cheapest model tier** (`--model haiku` / each assistant's
cheapest): confronting a claim against run evidence is mechanical, not deep
reasoning. Do not spend a frontier model here.

## Signal-only

This skill **never blocks** a commit, task, or merge. The syntactic gate already
blocks at commit; this is the signal for the "claimed done without running" gap.
It reports; the human decides — promote real gaps, archive the rest via
`/octopus:review-proposals`.

## Pairing

- `guardrails` bundle — the syntactic **block** at commit (formatter / typecheck / secret).
- `audit-grounding` — the semantic **signal** (invented conventions, unsupported facts).
- `audit-verification` — the verification **signal** (this skill). Together they are the local-guardrail triad.
