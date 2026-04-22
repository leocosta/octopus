# Spec: Pre-LLM Audit Pass

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-22 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-025 |

## Problem Statement

Audit skills (`money-review`, `security-scan`, `cross-stack-contract`, `tenant-scope-audit`) currently instruct the LLM to analyse the full diff of a PR. When the diff is large, the LLM reads irrelevant files before narrowing to the ones that matter, wasting tokens and increasing latency. There is no deterministic pre-filter that can terminate early if no relevant files exist.

## Goals

- Add a deterministic grep phase to each audit skill that runs before LLM analysis
- Produce a scoped diff containing only files relevant to the skill's domain
- Emit early-exit when no relevant files are found
- Centralise the pre-pass protocol in `skills/_shared/audit-pre-pass.md` so all audit skills reuse one implementation
- Reduce token consumption on large PRs without changing skill outputs

## Non-Goals

- Change severity classifications or finding formats
- Add new inspection checks to any audit skill
- Replace keyword-based triggers in lazy skill activation (separate feature, RM-022)
- Support non-git repos or remote diff sources

## Design

### Overview

**Pre-LLM audit pass** adds a deterministic grep phase to each audit skill before the LLM performs severity classification. Centralised in `skills/_shared/audit-pre-pass.md` (approach C). Pre-pass protocol: (1) file discovery via `git diff --name-only | grep -E patterns` → candidate list, (2) early exit if empty → "No relevant files found", (3) scoped diff for matching files only → LLM receives scoped diff not full diff. Token savings: eliminates full-diff reading + noise from irrelevant files.

### Detailed Design

**4.1 Frontmatter extension**

Each audit skill adds a `pre_pass:` block to the SKILL.md frontmatter, alongside `triggers:`:

```yaml
pre_pass:
  file_patterns: "<ERE matched against filenames from git diff --name-only>"
  line_patterns: "<ERE matched against added/changed lines within candidate files>"
```

`file_patterns` is required and drives the early-exit. `line_patterns` is optional — when present, it refines the candidate list to files containing at least one matching added/changed line.

**4.2 Shared fragment — `skills/_shared/audit-pre-pass.md`**

The fragment defines the four-step protocol that each skill's File Discovery section delegates to:

```
Step 1 — candidate files
  git diff --name-only <base>..<ref> | grep -E "<file_patterns>"
  Store as CANDIDATE_FILES.

Step 2 — early exit
  If CANDIDATE_FILES is empty → print "no <domain> changes detected" and stop.

Step 3 — optional line filter (when line_patterns is defined)
  For each file in CANDIDATE_FILES:
    git diff <base>..<ref> -- <file> | grep -E "^[+]" | grep -qE "<line_patterns>"
  Remove files that don't match. If all removed → early exit.

Step 4 — scoped diff output
  Print:
    ## Scoped files
    <CANDIDATE_FILES>
    <blank line>
    git diff <base>..<ref> -- <CANDIDATE_FILES>
  Pass this to the LLM in place of the full diff.
```

**4.3 Integration in the 4 audit skills**

The existing file-discovery section in each skill is **replaced** by a reference to the shared fragment. The section heading varies per skill:

| Skill | Section to replace |
|---|---|
| `money-review` | `## File Discovery` |
| `security-scan` | `## File Discovery` |
| `tenant-scope-audit` | `## File Discovery` |
| `cross-stack-contract` | `## Stack Discovery` |

Replacement content (heading retained, body replaced):

```markdown
## File Discovery   <!-- or ## Stack Discovery for cross-stack-contract -->

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Proceed to inspection checks only with the scoped diff produced by Step 4.
```

**4.4 Patterns per skill**

| Skill | file_patterns | line_patterns |
|---|---|---|
| `money-review` | `billing\|payment\|charge\|cobran\|split\|invoice\|subscription\|asaas\|stripe\|pix\|webhook\|refund\|reembolso\|tax\|taxa\|fee` | `PERCENT[_A-Z]*\s*=\|\bdecimal\b\|asaas\|stripe\|mercadopago\|webhook.*(signature\|hmac)` |
| `security-scan` | `auth\|jwt\|oauth\|secret\|token\|password\|credential\|permission\|role\|middleware\|\.env` | `password\|secret\|Bearer\|Authorization\|SQL\|querySelector` |
| `cross-stack-contract` | `controller\|endpoint\|route\|openapi\|swagger\|dto\|request\|response\|contract` | `\[Route\]\|\[HttpGet\]\|\[HttpPost\]\|app\.map\|MapGet\|MapPost\|fetch(\|axios\.` |
| `tenant-scope-audit` | `tenant\|org\|workspace\|organization\|scope` | `tenantId\|orgId\|workspaceId\|TenantId\|OrgId` |

### Migration / Backward Compatibility

- **No breaking changes for users** — invocation commands remain identical
- **No breaking changes for outputs** — findings, severities, and report format are unchanged
- **Skills without `pre_pass:`** continue to work without modification — the shared fragment is only invoked when referenced in the skill's File Discovery section
- **Migration of the 4 skills**: surgical replacement of the `## File Discovery` section + addition of `pre_pass:` to the frontmatter — no other sections affected
- **`_shared/audit-pre-pass.md`** is a new file with no conflicts

Regression risk: low. The only behavioral change is early-exit on PRs with no relevant files — which currently return empty findings or noise anyway.

## Implementation Plan

1. **Create `skills/_shared/audit-pre-pass.md`** — shared fragment with the full Pre-Pass protocol (Steps 1–4 per Detailed Design §4.2)

2. **Update `skills/money-review/SKILL.md`** — add `pre_pass:` frontmatter block with `file_patterns` and `line_patterns`; replace `## File Discovery` with shared fragment reference

3. **Update `skills/security-scan/SKILL.md`** — same, with security patterns (including `\.env`)

4. **Update `skills/cross-stack-contract/SKILL.md`** — same, with contract patterns; note: replace `## Stack Discovery` (not `## File Discovery`) with the shared fragment reference

5. **Update `skills/tenant-scope-audit/SKILL.md`** — same, with tenant patterns

6. **Add `tests/test_pre_llm_audit_pass.sh`** — grep-based tests: shared fragment exists and contains required sections; each skill has `pre_pass:` in frontmatter; each skill references the shared fragment; `\.env` present in security-scan patterns

## Context for Agents

**Knowledge modules**: audit-skills, shared-fragments, frontmatter-conventions
**Implementing roles**: general-purpose
**Related ADRs**: N/A
**Skills needed**: money-review, security-scan, cross-stack-contract, tenant-scope-audit
**Bundle**: audit

**Constraints**:
- Do not alter findings, severities, or output format of any audit skill
- Skills without `pre_pass:` in the frontmatter are not affected
- The shared fragment is pure markdown — no executable bash code

## Testing Strategy

Grep-based tests in `tests/test_pre_llm_audit_pass.sh`:

1. `skills/_shared/audit-pre-pass.md` exists
2. Shared fragment contains "Step 1", "Step 2", "Step 3", "Step 4"
3. Shared fragment contains "early exit" and "CANDIDATE_FILES"
4. `money-review/SKILL.md` contains `pre_pass:`
5. `security-scan/SKILL.md` contains `pre_pass:`
6. `cross-stack-contract/SKILL.md` contains `pre_pass:`
7. `tenant-scope-audit/SKILL.md` contains `pre_pass:`
8. `security-scan/SKILL.md` `file_patterns` contains `\.env`
9. Each of the 4 skills references `audit-pre-pass.md` in its File Discovery section
10. None of the 4 skills contains inline content in `## File Discovery` beyond the shared fragment reference

## Risks

- **Over-filtering**: if `file_patterns` is too narrow, legitimate files are excluded. Mitigation: start broad, refine based on false-negative reports.
- **Pattern drift**: as skills evolve, `pre_pass` patterns may fall out of sync with actual detection logic. Mitigation: patterns are reviewed as part of any inspection check update.
- **LLM ignores scoped diff**: the agent may re-run `git diff` without the file filter. Mitigation: the shared fragment instructs explicitly "pass this output to the LLM in place of the full diff."

## Changelog

- **2026-04-22** — Initial draft
