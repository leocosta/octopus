---
name: test-tdd
description: >
  Standalone red-green-refactor TDD — vertical tracer-bullet slices,
  integration-style tests against the public interface, hard ban on horizontal
  slicing (all tests then all code). Standalone so debug and isolated bugfixes
  can use it without the full implement workflow.
---

# Test-Driven Development Protocol

## Overview

TDD as an isolated discipline. The `implement` skill embeds the same
loop inside its broader workflow; `test-tdd` extracts it so any task —
a bug fix, a `debug` Phase 3, a small refactor — can run the loop
without invoking `implement` end-to-end.

This skill is *rigid*. The loop order is non-negotiable. Adaptation
happens in what you test, never in whether you test-first.

## When to Engage

Engage when:

- The user asks for TDD, test-first, red-green-refactor
- `debug` Phase 3 needs the loop for a regression test
- A new behaviour is being added to existing code and the user wants
  the test to drive the interface

Do **not** engage for:

- Pure refactors with no behaviour change — run the existing suite
  green instead
- Exploratory prototyping — use `prototype`, whose outputs are
  throwaway and waste tests

## The Loop

### Phase 1 — Plan the slice

Before any test is written, confirm with the user:

- The **public interface** under test (function signature, HTTP route,
  CLI invocation — whatever the caller sees)
- The **behaviours that matter** — not coverage, what the user cares
  about
- Whether any planned behaviour suggests a **deep module** — if so,
  name it before writing tests

Test names use CONTEXT.md vocabulary, not implementation jargon.

### Phase 2 — Tracer bullet

Write **one** test for **one** behaviour. Run it. Confirm red with the
expected failure message. Write the minimum code to pass. Run again.
Green.

A tracer bullet is a vertical slice — input → interface → output —
that exercises the full path end-to-end, however thin. The first
slice proves the wiring; subsequent slices add behaviour.

### Phase 3 — Loop

Repeat: one test → red → minimum code → green. One behaviour per
slice. Never skip ahead to write code for a test not yet written.

### Phase 4 — Refactor on green

Only when the suite is green: extract duplication, deepen shallow
modules, apply SOLID where it earns its keep. Re-run after every
refactor step.

**Never refactor in red.** This is the phase gate the skill enforces.

## The Horizontal-Slicing Ban

The dominant anti-pattern: writing all the tests first, then all the
code. Why it fails:

- Tests written before the code is shaped test **imagined** behaviour,
  not real behaviour
- They couple to internal names — a rename breaks them even though
  behaviour is unchanged
- They produce tests that slow refactoring instead of enabling it

A good TDD test breaks when **behaviour changes**, not when
**structure changes**. Horizontal slicing reliably produces the
latter.

## What to Test (and What Not)

Confirm with the user; do not assume coverage targets. Test the happy
paths, edge cases, and error paths the user named. If the user did
not name it, ask before testing it.

## Anti-Patterns

- Writing a second test before the first is green
- Refactoring while any test is red
- Asserting on internal state instead of observable behaviour
- Test names that describe the function (`testGetUser`) instead of the
  behaviour (`returns user when id matches existing record`)
- Mocking what you own — mock at system boundaries, not internal
  collaborators
- Skipping the red step

## Integration with Other Skills

- **`implement`** — embeds this loop inside the feature workflow;
  `test-tdd` is invoked standalone when only the loop is needed
- **`debug`** — Phase 3 (regression test first) calls `test-tdd`
- **`test-e2e`** — sibling skill for end-to-end tests; `test-tdd`
  stays at the unit / integration boundary
- **`rules/common/testing.md`** — static rules that always apply;
  `test-tdd` adds the loop discipline on top
