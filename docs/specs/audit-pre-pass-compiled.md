# Spec: Audit Pre-Pass Compiled

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-08-03 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-172 (Cluster 31 — review-engine parity) |

## Problem Statement

`skills/_shared/audit-pre-pass.md` (41 lines) and `skills/_shared/audit-cache.md`
(52 lines) describe work that is entirely mechanical — `git diff --name-only`
filtered by a regex, an early exit, a second line-level filter, and a
`sha256`-keyed cache lookup — as **protocols the model is asked to follow**. Both
fragments are loaded into every dispatched `audit-*` sub-agent, and every saving
they promise is conditional on the model choosing to execute them faithfully.

Three consequences, in descending order of cost:

1. **The cache is optional in practice.** A repeat review of an unchanged diff
   should cost a `sha256` and a file read. Today it costs a sub-agent spin-up plus
   a model deciding whether to compute the key. This lands on the fix-and-re-run
   loop, which happens several times per PR.
2. **The early exit is not free.** An audit dispatched against a domain with no
   matching files should cost nothing; today it costs the spawn plus the protocol
   read before the model concludes there is nothing to do.
3. **The protocol text is paid per dispatch.** ~1.2k tokens of instructions
   shipped into each of up to four concurrent sub-agents, every review.

The existing tests confirm the diagnosis rather than contradicting it.
`tests/test_pre_llm_audit_pass.sh` asserts the fragment exists and contains the
strings `Step 1`…`Step 4`, `early exit` and `CANDIDATE_FILES`, and that each skill
*mentions* the filename. `tests/test_audit_output_cache.sh` does the same with
`Cache Check`, `CACHE_KEY` and `sha256`. Neither executes a `git diff`, computes a
key, or observes a cache hit — the suite tests that the prose is still there.

## Goals

- The pre-pass and cache run as **code**, before any model call, with the same
  observable semantics they specify today.
- **No protocol text in the sub-agent prompt.** Each `audit-*` SKILL.md keeps a
  one-line reference in place of the embedded procedure.
- **A cache hit costs no model call at all** — the orchestrator resolves it before
  dispatch, so a hit does not spawn a sub-agent.
- **An empty candidate set costs no model call** — same mechanism.
- Tests **execute** the implementation against git fixtures and assert behaviour:
  early exit, line-filter removal, cache hit, cache invalidation on SKILL.md
  change, and `.gitignore` guard.
- Measured token reduction of 8–15% on a representative mid-size review, recorded
  in the PR (this is the RM-172 estimate; the spec is done when the real number is
  known, not when it matches).

## Non-Goals

- **No change to audit semantics.** `file_patterns` and `line_patterns` values are
  ported verbatim; a diff that reaches the LLM today must reach it after this
  change. Any pattern edit is a separate PR.
- **Not unifying the two pattern sources** (see Risks) — this spec documents the
  overlap and picks the frontmatter as authoritative for the pre-pass only.
- **Not RM-170/RM-171.** Anchor verification and the reflection pass are separate
  items; nothing here anticipates them beyond leaving the output shape stable.
- **Not a new skill** — no bundle registration needed.

## Design

### Overview

Two sourceable bash libraries under `cli/lib/`, following the established
`cli/lib/audit-map.sh` pattern (documented public API in the header, sourced by
hooks, callable from tests):

- `cli/lib/audit-prepass.sh` — resolves a skill's `pre_pass` frontmatter, produces
  the scoped file list and scoped diff, or reports "no candidates".
- `cli/lib/audit-cache.sh` — computes the cache key from the scoped diff plus the
  SKILL.md hash, reports hit/miss, reads and writes the cache entry, and maintains
  the `.gitignore` guard.

They are called from **two** places, and must be idempotent so that both paths are
safe:

1. **The orchestrator** (`commands/codereview.md` Phase 2, `pr-review` by
   reference) calls them *before* dispatching. On "no candidates" or a cache hit,
   it does not spawn the sub-agent at all — this is where the saving is.
2. **The skill itself**, when invoked directly (`/octopus:audit-money`), calls the
   same entry point as its first step. This keeps standalone invocation working
   and is a no-op cost when the orchestrator already resolved it.

### Detailed Design

**`audit-prepass.sh` public API**

```
audit_prepass_patterns <skill-name>              → prints "file_patterns\nline_patterns"
audit_prepass_candidates <skill-name> <base> <ref> → prints candidate paths, one per line
                                                     exit 1 when the set is empty
audit_prepass_diff <skill-name> <base> <ref>     → prints the scoped diff block
                                                     (## Scoped files header + git diff)
```

Frontmatter is read from `skills/<name>/SKILL.md` between the leading `---`
markers. The parser must handle the nested two-space `pre_pass:` block already in
use; the flat `.octopus.yml` reader is **not** reusable here (see
`project_octopus_feature_config` — nested config needs its own reader).

Semantics ported verbatim from the fragment: candidates come from
`git diff --name-only <base>..<ref>` filtered by `file_patterns`; when
`line_patterns` is present, a file survives only if an **added** line
(`^+`) matches it; an empty set at either stage is the early exit.

**`audit-cache.sh` public API**

```
audit_cache_key <skill-name> <scoped-diff-file>  → prints the 64-char key
audit_cache_lookup <skill-name> <key>            → prints the cached body (frontmatter
                                                   stripped), exit 1 on miss
audit_cache_write <skill-name> <key> <body-file> → writes .octopus/cache/<skill>/<key>.md
```

Key = `sha256(scoped_diff || sha256(SKILL.md))`, matching the current fragment so
existing cache entries stay valid. The cached file keeps its current frontmatter
(`skill`, `ref`, `base`, `created_at`) and body.

**Hash portability.** The fragment hardcodes `sha256sum`, which does not exist on
macOS by default (`shasum -a 256` does) and is absent from some Windows git-bash
setups. The library resolves the available implementation once and fails with a
clear message if neither is present. This is a latent bug in the current protocol,
fixed here rather than ported.

**Orchestrator contract.** For each matched audit, the orchestrator resolves
`candidates → cache` and takes one of three paths: skip (no candidates), emit the
cached report (hit), or dispatch the sub-agent with the scoped diff already in the
prompt (miss). On the miss path it writes the cache after the sub-agent returns.

### Migration / Backward Compatibility

- The `_shared/*.md` fragments are **replaced by a one-line pointer**, not deleted:
  each keeps its filename so `doc-api` and `audit-all`, which reference them, do
  not break, and so an agent reading a SKILL.md still finds a definition of the
  contract.
- Each of the four SKILL.md files swaps its "Follow the Pre-Pass protocol / Cache
  protocol" block for a single line naming the entry point.
- Cache keys are unchanged, so entries written before this change still hit.
- The two existing tests are **rewritten**, not extended — their current assertions
  (grep for prose) become meaningless once the prose moves. Preserve the one
  assertion worth keeping: that each of the four skills still declares `pre_pass:`
  in its frontmatter.

## Implementation Plan

1. `cli/lib/audit-prepass.sh` — frontmatter reader, candidates, scoped diff.
   No callers yet.
2. `tests/test_audit_prepass.sh` — git fixture repo; assert candidate filtering,
   line-filter removal, early exit, and verbatim parity with the four skills'
   current patterns.
3. `cli/lib/audit-cache.sh` — key, lookup, write, hash-tool resolution,
   `.gitignore` guard.
4. `tests/test_audit_cache.sh` — assert miss → write → hit, invalidation when the
   SKILL.md changes, and key stability against a pinned known-good key.
5. Swap the four SKILL.md protocol blocks for the one-line reference; reduce the
   two `_shared` fragments to pointers.
6. Update `commands/codereview.md` Phase 2 with the three-path contract; update
   `commands/pr-review.md` where it references those phases.
7. Rewrite `tests/test_pre_llm_audit_pass.sh` and `tests/test_audit_output_cache.sh`
   against the executable behaviour.
8. Measure: run a representative review before/after, record the token delta in
   the PR body.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [architect]
**Related ADRs**: TBD — check whether the capability/delivery ADRs (ADR-011) bear
on shipping a new `cli/lib/` entry point to downstream repos.
**Skills needed**: [implement, test-tdd]
**Bundle**: N/A — no new skill.

**Constraints**:
- Pure bash, no external dependencies beyond `git` and a sha256 implementation.
- Must work on Linux, macOS and git-bash on Windows (`install.ps1` is a supported
  install path).
- Follow the `cli/lib/audit-map.sh` conventions: documented public API in the file
  header, sourceable, no side effects on source.
- Audit semantics unchanged — verbatim pattern parity is a test, not a review note.
- Never bypass the cache silently: a hit must be visible in the report output.

## Testing Strategy

Executable tests against a temporary git repository built per test case
(`git init`, commit a base, commit a change), not against the live repo:

- **Pre-pass**: file matches `file_patterns`; file matched at path level but
  filtered out by `line_patterns`; empty candidate set → early exit; a change
  touching only removed lines (`^-`) does not match `line_patterns`.
- **Parity**: for each of the four skills, the compiled candidate set equals the
  set produced by the literal shell pipeline in the current fragment.
- **Cache**: miss → write → hit; a modified SKILL.md invalidates; a modified diff
  invalidates; `.gitignore` gains `.octopus/cache/` exactly once.
- **Portability**: hash resolution works when only `shasum` is present (simulate by
  masking `sha256sum` on `PATH`).
- **Regression**: the four skills still declare `pre_pass:` frontmatter.

## Measurement

Measured on implementation, replacing the RM-172 projection.

**Static text, per dispatched audit** — the two fragments a sub-agent previously
had to read:

| Item | Before | After |
|---|---|---|
| `_shared/audit-pre-pass.md` | 1,273 B (~318 tok) | not read at runtime |
| `_shared/audit-cache.md` | 1,361 B (~340 tok) | not read at runtime |
| `## File Discovery` section | ~300–500 B | ~570–755 B (+65–69 tok) |
| **Net per dispatch** | — | **~590 tokens saved** |

With up to four audits matched, that is ~2.4k tokens per review — closer to **5%**
of a mid-size run than the 8–15% RM-172 projected. The projection assumed ~1.2k
tokens of protocol per dispatch; the fragments are 658.

**Not measured, and dominant.** The larger saving is structural: on `skip` and
`cached` no sub-agent is spawned at all, so the review avoids a system prompt,
tool definitions, the model's own reasoning and its output — all of which exceed
658 tokens by a wide margin. Quantifying it needs an instrumented end-to-end
review, which is RM-175 territory. Until then the honest claim is: ~5% measured
on static text, with the structural saving real but unquantified.

The RM-172 roadmap entry should be corrected to say this once measured end to end.

## Risks

- **Two sources of path patterns.** `cli/lib/audit-map.sh` resolves patterns from
  `docs/<name>/patterns.md` → `skills/<name>/templates/patterns.md`, while the
  pre-pass uses `pre_pass.file_patterns` from the SKILL.md frontmatter. They can
  disagree — the map decides *whether* an audit is dispatched, the pre-pass decides
  *which files it sees*. This spec keeps both and treats the frontmatter as
  authoritative for the pre-pass only. Unifying them is a follow-up RM; doing it
  here would change audit semantics and break the parity test that makes this
  change safe.
- **Stale cache surfacing as a clean review.** A cache hit today is chosen by the
  model and is rare; making it reliable makes staleness matter. Mitigated by
  keying on the diff plus the SKILL.md hash — but a rule change *outside* the
  SKILL.md (e.g. `rules/common/`) would not invalidate. Consider including the
  active ruleset hash in the key.
- **Downstream delivery.** Skills reach adopting repos through `setup.sh`; a
  SKILL.md that references `cli/lib/audit-prepass.sh` must resolve in an installed
  repo, not only in this one. Verify against the install path before merging.
- **The estimate may not hold.** 8–15% is projected from the fragment size and
  dispatch count, not measured. If the real number is materially lower, that is a
  finding to report, not a number to defend.

## Changelog

- **2026-08-03** — Initial draft (RM-172)
