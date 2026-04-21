# ADR 001: Checkbox-flip commit strategy for /octopus:implement walker

## Status

Accepted — 2026-04-21

## Context

RM-037 extends `/octopus:implement` with a `--plan` walker that
marks each plan task `- [x]` as it completes. The flip is a
one-line edit in `docs/plans/<slug>.md`. We need to decide how
this edit reaches git.

Two candidate strategies were evaluated via a spike in a
throw-away worktree:

- **Strategy A — `git commit --amend --no-edit`.** The walker
  folds the plan-file flip into the task's own commit.
- **Strategy B — separate commit.** The walker emits a
  `docs(plans): mark task N complete` commit after the task's
  own commit.

Spike results:

- Strategy A — one commit per task, subject preserved from the
  TDD skeleton (`feat(spike): pretend task N commit`). History
  stays at N commits for N tasks.
- Strategy B — two commits per task. Walking five tasks would
  yield ten commits: five feature commits and five `docs(plans):
  mark task N complete` commits interleaved.

## Decision

Adopt **Strategy A** (amend) for the walker's steady-state flow.

## Rationale

- History stays linear and readable — one commit per task, whose
  subject already describes the task. Reviewers browsing
  `git log` see N entries for N tasks, not 2N.
- SHA rewrite is contained: the walker amends immediately after
  the task's own commit, before any `git push`. Users who push
  mid-walk can already hit the well-documented "don't amend
  pushed commits" rule; the walker does not push on their
  behalf.
- GPG-signing repos pay a re-sign cost on the amend; this is the
  same cost a developer running the TDD loop manually would pay
  when fixing a typo in their commit message.

## Consequences

- Walkers in GPG-signed repos re-sign the task commit once per
  task (acceptable).
- Users who have pushed mid-walk before `--amend` happens must
  force-push (uncommon path; documented in the command body).
- If a future need arises for the plan-file flip to stand alone
  (e.g. for a CI status checker), switching to Strategy B is a
  one-line change in the command instructions. Listed here so
  the reversal cost is explicit.
