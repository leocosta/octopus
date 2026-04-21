<!--
plan-skeleton.md — frozen output template for /octopus:doc-plan.

This file captures the writing-plans vocabulary that
downstream executors (superpowers:executing-plans,
superpowers:subagent-driven-development, and the future
/octopus:implement --plan walker in RM-037) rely on.

Structural tests in tests/test_doc_plan.sh assert that
/octopus:doc-plan emits plans matching this skeleton on the
headings, the File Structure table, and the Task skeleton.
User-specific content (goal, tech stack, task code blocks)
is free text.

Do NOT drift this file without also updating the tests.
-->

# <Feature Name> Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** <one sentence>

**Architecture:** <2-3 sentences>

**Tech Stack:** <key technologies>

**Spec:** `docs/specs/<slug>.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `exact/path` | create / modify | what it does |

---

## Task 1: <Component Name>

**Files:**
- Create: `exact/path`
- Modify: `exact/path:line-range`

- [ ] **Step 1: Write the failing test**

```language
test code
```

- [ ] **Step 2: Run test to verify it fails**

Run: `command`
Expected: FAIL with "reason"

- [ ] **Step 3: Write minimal implementation**

```language
implementation
```

- [ ] **Step 4: Run test to verify it passes**

Run: `command`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add <paths>
git commit -m "type(scope): summary"
```
