# Spec: Audit Output Cache

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-22 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-026 |

## Problem Statement

Audit skills (`money-review`, `security-scan`, `cross-stack-contract`, `tenant-scope-audit`) re-run full LLM analysis every time they are invoked, even when the PR diff hasn't changed. On busy review cycles this wastes tokens and adds latency for identical work.

## Goals

- Cache audit output keyed by `sha256(scoped diff + skill version)` in `.octopus/cache/<skill>/<hash>.md`
- Return cached result immediately on hit — zero LLM tokens
- Write result to cache on miss after LLM analysis completes
- Centralise the cache protocol in `skills/_shared/audit-cache.md` (same pattern as `audit-pre-pass.md`)
- Cache persists across sessions until the diff or skill version changes

## Non-Goals

- CLI-level caching (no changes to the `octopus` binary)
- Cross-machine cache sharing
- TTL-based expiry — cache is keyed by content; invalidation is implicit when diff changes
- Caching partial results or per-finding granularity

## Design

### Overview

**Audit Output Cache** adds a cache layer to audit skills so that re-running the same audit on an unchanged diff costs zero tokens. Each skill checks for a cached result in `.octopus/cache/<skill>/<hash>.md` before invoking LLM analysis. The cache key is `sha256(scoped diff + skill version)`. On hit: the cached markdown is returned as-is. On miss: the LLM runs normally and the result is written to the cache file. A new shared fragment `skills/_shared/audit-cache.md` defines the check/write protocol, composing with the existing `audit-pre-pass.md` (pre-pass runs first, then cache check, then LLM).

### Detailed Design

**4.1 Cache key**

```
key = sha256(scoped_diff + skill_file_hash)
scoped_diff     = output of audit-pre-pass.md Step 4
skill_file_hash = sha256(SKILL.md content)
```

Computed via:
```bash
echo -n "<scoped_diff><skill_file_content>" | sha256sum | cut -c1-64
```

Cache path: `.octopus/cache/<skill-name>/<key>.md`

**4.2 Cache file format**

```markdown
---
skill: money-review
ref: <ref argument passed to the skill>
base: <base branch>
created_at: YYYY-MM-DDTHH:MM:SSZ
---

<full audit output — exactly what would have been printed to the user>
```

**4.3 Shared fragment — `skills/_shared/audit-cache.md`**

Protocol inserted **after** `audit-pre-pass.md` Step 4 and **before** LLM inspection:

```
Cache Check (before LLM analysis):

1. Compute CACHE_KEY:
   a. Read SKILL.md content → SKILL_HASH via sha256sum
   b. Concatenate SCOPED_DIFF (from pre-pass Step 4) + SKILL_HASH
   c. CACHE_KEY = sha256 of concatenation, first 64 chars

2. Check for hit:
   CACHE_FILE = .octopus/cache/<skill-name>/<CACHE_KEY>.md
   If CACHE_FILE exists → print its body (strip frontmatter) and stop.

3. On miss: proceed with LLM inspection normally.

Cache Write (after LLM produces output):

4. Create .octopus/cache/<skill-name>/ if absent.
5. Write CACHE_FILE with frontmatter (skill, ref, base, created_at) + audit output.
```

**4.4 Integration in the 4 audit skills**

Each skill adds one line after the `audit-pre-pass.md` reference in its discovery section:

```markdown
## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Then follow the Cache protocol in `skills/_shared/audit-cache.md` before proceeding to inspection checks.
```

**4.5 `.gitignore` guard**

The shared fragment instructs the agent to verify that `.octopus/cache/` is present in the repo's `.gitignore` and append it if absent — on the first cache write only.

### Migration / Backward Compatibility

- **No breaking changes** — skill invocations remain identical; the cache is transparent to users
- **First run after the feature**: cache miss → current behavior; result is written for subsequent runs
- **Skills without cache wiring**: skills that do not reference `audit-cache.md` continue working unchanged
- **Manual cache clear**: `rm -rf .octopus/cache/` — no special command required
- **`.gitignore` guard**: the fragment checks and appends `.octopus/cache/` automatically on first write; repos that already have `.octopus/` in `.gitignore` are unaffected

Regression risk: low. The only new behavior is returning cached output instead of invoking the LLM — the output is content-identical.

## Implementation Plan

1. **Create `skills/_shared/audit-cache.md`** — shared fragment with the full Cache Check + Cache Write protocol (§4.3)

2. **Update `skills/money-review/SKILL.md`** — add reference to `audit-cache.md` in File Discovery, after the `audit-pre-pass.md` line

3. **Update `skills/security-scan/SKILL.md`** — same

4. **Update `skills/cross-stack-contract/SKILL.md`** — same (File Discovery section)

5. **Update `skills/tenant-scope-audit/SKILL.md`** — same

6. **Add `tests/test_audit_output_cache.sh`** — grep-based: shared fragment exists and contains protocol markers; each skill references `audit-cache.md`; `.octopus/cache` mentioned in fragment

## Context for Agents

**Knowledge modules**: audit-skills, shared-fragments, frontmatter-conventions
**Implementing roles**: general-purpose
**Related ADRs**: N/A
**Skills needed**: money-review, security-scan, cross-stack-contract, tenant-scope-audit
**Bundle**: audit

**Constraints**:
- No changes to the `octopus` CLI
- The shared fragment is pure markdown — no executable bash code in the file
- Cache is transparent to the user — output identical to non-cached runs
- `.octopus/cache/` must be added to `.gitignore` when absent

## Testing Strategy

Grep-based tests in `tests/test_audit_output_cache.sh`:

1. `skills/_shared/audit-cache.md` exists
2. Fragment contains "Cache Check" and "Cache Write"
3. Fragment contains "CACHE_KEY" and "CACHE_FILE"
4. Fragment contains "sha256"
5. Fragment contains `.octopus/cache`
6. Fragment contains "created_at"
7. `money-review/SKILL.md` references `audit-cache.md`
8. `security-scan/SKILL.md` references `audit-cache.md`
9. `cross-stack-contract/SKILL.md` references `audit-cache.md`
10. `tenant-scope-audit/SKILL.md` references `audit-cache.md`

## Risks

- **LLM skips cache write**: the agent may produce the output but fail to write the file. Mitigation: the fragment includes an explicit instruction to write before returning the result.
- **Hash collision**: sha256 truncated to 64 chars has negligible collision probability in practice.
- **Large cache files**: audit outputs can be verbose on large PRs. Mitigation: cache files are per-skill and per-diff; stale entries are never read (content-keyed), so they only grow, not bloat active runs. Users can `rm -rf .octopus/cache/` at any time.
- **`.gitignore` write fails**: if the repo root is read-only or `.gitignore` doesn't exist. Mitigation: the fragment instructs the agent to warn and continue rather than abort.

## Changelog

- **2026-04-22** — Initial draft
