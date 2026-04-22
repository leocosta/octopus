# Post-Merge Audit Hook Implementation Plan (RM-029)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Git `pre-push` hook that reads the diff about to be pushed, maps touched files/keywords to relevant Octopus audit skills, and prints advisory suggestions. Never blocks the push, never runs audits.

**Architecture:** `hooks/git/pre-push-audit-suggest.sh` (hook body) + `cli/lib/audit-map.sh` (pure mapping library). Installed by `setup.sh` when `workflow: true` and at least one audit skill is present. Opt-out via `postMergeAuditHook: false` in `.octopus.yml`.

**Tech Stack:** Pure bash. Grep-based tests using fixture diffs.

**Spec:** `docs/specs/post-merge-audit-hook.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `skills/money-review/templates/patterns.md` | modify | Standardize to `## Path tokens` + `## Content regex` headings |
| `skills/tenant-scope-audit/templates/patterns.md` | modify | Add `## Path tokens` + `## Content regex` headings |
| `skills/security-scan/templates/patterns.md` | create | New patterns file with standard headings |
| `cli/lib/audit-map.sh` | create | Pure function library: parse patterns.md cascade, match diff |
| `tests/test_audit_map.sh` | create | Fixture-diff unit tests for audit-map.sh |
| `hooks/git/pre-push-audit-suggest.sh` | create | Hook body: reads stdin, computes diff, prints blocklet |
| `setup.sh` | modify | Parse `postMergeAuditHook:`, add `deliver_git_hooks()` |
| `tests/test_post_merge_audit_hook.sh` | create | Install tests: fresh, opt-out, chain mode |
| `docs/roadmap.md` | modify | Mark RM-029 completed |
| `docs/specs/post-merge-audit-hook.md` | modify | Flip status to Implemented |

---

## Task 1: Standardize patterns.md schema

- [ ] Migrate `skills/money-review/templates/patterns.md` (rename headings)
- [ ] Migrate `skills/tenant-scope-audit/templates/patterns.md` (add path tokens + content regex)
- [ ] Create `skills/security-scan/templates/patterns.md`

## Task 2: Create `cli/lib/audit-map.sh`

## Task 3: Create `tests/test_audit_map.sh`

## Task 4: Create `hooks/git/pre-push-audit-suggest.sh`

## Task 5: Modify `setup.sh`

## Task 6: Create `tests/test_post_merge_audit_hook.sh`

## Task 7: Update roadmap and spec
