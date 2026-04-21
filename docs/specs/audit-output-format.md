# Spec: Shared audit-skill conventions

**Status:** Completed (2026-04-20)
**Roadmap:** RM-024

## Problem

Three pre-merge audit skills (`money-review`, `tenant-scope-audit`,
`cross-stack-contract`) each repeated ~60 lines of preamble documenting
the same conventions: invocation flags, override-file cascade,
severity output format, `--write-report` frontmatter, common errors,
and composition note. Maintenance drift was a real risk — a fix to
the severity format had to be applied in three places.

## Decision

Extract shared conventions into `skills/_shared/audit-output-format.md`.
Each audit SKILL.md references it and keeps only the skill-specific
parts: inspection families / checks, config keys, per-skill flags,
finding-ID prefixes, skill-specific error wording.

No new tooling. No frontmatter sync check (unlike RM-034's task-routing
fragment, which demanded byte-identical copies). Here, each skill
paraphrases the shared convention and links to it — reviewers
maintain coherence manually.

## Impact

Line counts after refactor (total includes the new shared file):

| File | Before | After | Δ |
|---|---:|---:|---:|
| `skills/money-review/SKILL.md` | 233 | 197 | −15% |
| `skills/tenant-scope-audit/SKILL.md` | 245 | 203 | −17% |
| `skills/cross-stack-contract/SKILL.md` | 250 | 217 | −13% |
| `skills/_shared/audit-output-format.md` | — | 114 | new |
| **Total** | 728 | 731 | +3 |

Net source bytes are unchanged; the win is **single-source truth**.
Real token savings arrive when RM-022 (lazy skill activation) teaches
concatenators to include `_shared/audit-output-format.md` once instead
of re-including equivalent text inside every audit SKILL.md.

## Tests

`tests/test_money_review.sh`, `tests/test_tenant_scope_audit.sh`, and
`tests/test_cross_stack_contract.sh` now look for shared conventions
(severity emojis, `docs/reviews/` path, override cascade, confidence
labels) across both the SKILL.md and the shared file, via a
`grep_docs` helper.

## Not in scope

- Byte-level enforcement between SKILL.md and the shared file (the
  shared file is descriptive, not copy-pasted).
- Extending this to `security-scan` or `audit-all` — both use a
  different output contract.
