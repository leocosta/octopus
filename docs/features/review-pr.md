# Receiving-Code-Review

The Octopus PR-feedback discipline — active by default whenever
a task involves processing reviewer comments. The third workflow
skill in the `starter` bundle, alongside `implement` (features)
and `debugging` (bugs).

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
  `debugging`)

## Enable

The `starter` bundle includes `receiving-code-review`, so a
standard `octopus setup` run delivers it. If you use an explicit
`skills:` list in `.octopus.yml`, add:

```yaml
skills:
  - receiving-code-review
```

## Explicit invocation

```
/octopus:receiving-code-review <pr-or-comment-ref>
```

## Relationship to other skills

- `/octopus:pr-comments` — mechanics of the feedback loop.
  `receiving-code-review` supplies discipline per comment.
- `implement` — when a comment asks for a code change, its five
  practices drive the edit after this skill's five rules
  validate the ask.
- `debugging` — when a comment flags a bug, hand off; Rule 1
  still runs first.
- `rules/common/*` — always-on static rules. Never duplicated
  here.
- `superpowers:receiving-code-review` — when installed, wins per
  rule on the practices it already covers.

## Extension point

The `## Task Routing` section is a v1 stub reserved for RM-034,
which will auto-dispatch to the right companion skill based on
comment content (`money-review` for billing comments,
`tenant-scope-audit` for multi-tenant data access,
`cross-stack-contract` for cross-layer concerns, `debugging` for
reported bugs).

## Review before merging

The skill is guidance, not a gate. Treat anti-pattern violations
(performative change, generic-comment inference,
preference-as-authority) as review blockers; the skill itself
never fails the build.
