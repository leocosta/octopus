# Receiving-Code-Review

The Octopus PR-feedback discipline — active by default whenever
a task involves processing reviewer comments. The third workflow
skill in the `starter` bundle, alongside `implement` (features)
and `debug` (bugs).

The skill codifies five rules:

1. **Verify the critique against the code** — read the code the
   reviewer pointed at before accepting the feedback. If the
   reviewer is wrong, say so politely with evidence.
2. **Ask for evidence on generic comments** — "this is ugly",
   "seems wrong" cannot be acted on. Ask what specifically.
3. **Separate reasoned feedback from preference** — technical
   reasoning gets weight; preference is a negotiation, not an
   instruction.
4. **Never make performative changes** — never edit code just to
   close a thread without understanding the concern.
5. **Ask for clarification on ambiguity** — when the comment
   allows multiple readings, ask before acting. One clarifying
   question beats a second round of feedback.

## Post-fix loop

After the five rules end (the right change has been applied to
each comment), the skill runs a single post-fix turn that closes
the loop without requiring a separate command:

- **Commit** — one batch commit covering the review-driven
  edits, message proposed by the agent.
- **Push** — automatic when the branch already tracks an
  upstream; explicit confirmation when `-u` is needed.
- **Reply inline** — canned `Addressed in <sha>.` for direct
  fixes; contextual phrasing for push-back or partial action
  (`Kept current behavior because <reason> — <sha>.`).
- **Resolve threads** — closes threads that ended in a fix or a
  reasoned push-back. Threads pending clarification (Rule 5)
  stay open by design.

The menu is single-shot: approve everything in one word, edit
any line in place, or skip individual items.

## When to use

The skill engages automatically whenever a task involves
processing PR feedback — `/octopus:pr-comments <n>`, a reviewer
left a comment, the user quotes a reviewer's message. It does
not engage for:

- Writing a review for someone else's PR (that is
  `/octopus:pr-review`)
- Feature work that doesn't originate from a comment (that is
  `implement`)
- Bug triage that doesn't originate from a comment (that is
  `debug`)

## Enable

The `starter` bundle includes `respond-to-review`, so a
standard `octopus setup` run delivers it. If you use an explicit
`skills:` list in `.octopus.yml`, add:

```yaml
skills:
  - respond-to-review
```

## Explicit invocation

```
/octopus:respond-to-review <pr-or-comment-ref>
```

## Relationship to other skills

- `/octopus:pr-comments` — alternative entry point for walking
  a PR's threads from scratch. `respond-to-review` is
  end-to-end (five rules + post-fix loop) and does not require
  it.
- `implement` — when a comment asks for a code change, its five
  practices drive the edit after this skill's five rules
  validate the ask.
- `debug` — when a comment flags a bug, hand off; Rule 1
  still runs first.
- `rules/common/*` — always-on static rules. Never duplicated
  here.
- `superpowers:receiving-code-review` — when installed, wins per
  rule on the practices it already covers.

## Extension point

The `## Task Routing` section is a v1 stub reserved for RM-034,
which will auto-dispatch to the right companion skill based on
comment content (`audit-money` for billing comments,
`audit-tenant` for multi-tenant data access,
`review-contracts` for cross-layer concerns, `debug` for
reported bugs).

## Review before merging

The skill is guidance, not a gate. Treat anti-pattern violations
(performative change, generic-comment inference,
preference-as-authority) as review blockers; the skill itself
never fails the build.
