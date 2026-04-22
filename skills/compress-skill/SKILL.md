---
name: compress-skill
description: >
  Shrink a SKILL.md without changing its meaning. Deterministic
  cleanup pass first, LLM rewrite pass only if the target is not met.
  Anchors extracted from the skill's test file are preserved;
  frontmatter, headings, and code blocks are never modified. Dry-run
  by default; `--apply` writes the result.
triggers:
  paths: ["skills/**/*.md", ".octopus/**", "octopus/**"]
  keywords: []
  tools: []
---

# Compress-Skill Protocol

## Overview

`SKILL.md` files drift into verbosity as authors add caveats,
examples, and meta prose. Each extra line lands in the context window
of every session that loads the skill. This skill compresses a single
`SKILL.md` in place, preserving semantics and every string the
skill's own tests depend on.

It is the in-skill counterpart to RM-024 (cross-skill dedup). Run
both before assuming a skill is "lean".

## Invocation

```
/octopus:compress-skill <skill-name> [--apply] [--target=25] [--max-loss=5] [--heuristics-only]
```

- `<skill-name>` — required. Must match a directory under `skills/`.
- `--apply` — write the compressed SKILL.md back. Without this flag
  the protocol prints a diff only.
- `--target=<pct>` — desired compression ratio. Default: `25`.
- `--max-loss=<pct>` — abort if the LLM pass flags more than this
  fraction of content as "potentially semantic-changing". Default:
  `5`.
- `--heuristics-only` — skip the LLM pass. Useful in CI or offline
  contexts.

## Inputs

1. `skills/<skill-name>/SKILL.md` — the file to compress.
2. `tests/test_<skill-name>.sh` (when present) — parsed for
   **anchors**: every literal string passed to `grep -q` /
   `grep -qE`. These strings MUST survive compression.
3. `skills/_shared/*.md` references — if the SKILL.md links to a
   shared file, the shared file is read as context but never
   modified.

If the target SKILL.md has uncommitted changes, warn and require
`--force` before proceeding — otherwise the review diff would mix
user edits with compression output.

## Step 1 — Deterministic cleanup

Apply before any LLM call. Each rule is reversible and semantic-neutral.

1. **Collapse blank runs.** Consecutive blank lines → a single blank
   line.
2. **Trim trailing whitespace** on every line.
3. **Remove meta prose.** Drop lines matching any of:
   - `^This (section|skill) (describes|explains|covers)\b`
   - `^As mentioned (above|earlier)\b`
   - `^Note that\b` (when the rest of the line restates the
     surrounding paragraph)
   - `^In other words,\b`
4. **Shorten example lists.** Any bullet list introduced by
   `e.g.`, `for example`, or `such as` with more than 3 items
   → keep the first 3 + `…`.
5. **Collapse duplicated bullets.** When a bullet restates the
   preceding sentence verbatim, drop the bullet.

Run in that order. Re-measure size after each rule. If the target
ratio is hit, skip Step 2.

## Step 2 — LLM rewrite (skipped when `--heuristics-only`)

Only when Step 1 did not hit `--target`.

1. Load `skills/compress-skill/templates/prompt.md`.
2. Send to the LLM: the post-Step-1 text, the anchor allow-list, the
   target ratio, and the max-loss threshold.
3. Expect back a JSON envelope with:
   - `compressed`: the new text.
   - `changes`: array of `{passage, action, reason}` entries for
     every merge / deletion / rewrite. `action ∈ {merge, delete,
     rephrase}`.
   - `semantic_risk_pct`: model's self-estimate of how much content
     is semantically at-risk.

Abort when `semantic_risk_pct > --max-loss`, printing the offending
`changes` entries.

## Invariants (enforced after both steps)

Before writing or printing output, verify — in order:

1. **Frontmatter is byte-identical** to the input (everything
   between the opening `---` and the next `---`).
2. **Every anchor string** from Step-0 test parsing is present in
   the compressed output.
3. **Every `##` / `###` heading** from the input appears in the
   output with the same text.
4. **Every fenced code block** (```…```) from the input appears
   verbatim in the output (content and language tag).

If any invariant fails, abort and print which invariant broke, which
element is missing, and the line number of the mismatch. Do not
write the file.

## Output

**Dry-run (no `--apply`):**

```
## Compression preview — skills/<name>/SKILL.md

before: <N> lines / <M> bytes
after:  <N'> lines / <M'> bytes
Δ:      −<X>% bytes, −<Y>% lines
pass:   heuristics [+ llm]

## Diff
<unified diff, three context lines>

## Semantic-risk report
- <action>: <short description> [<section>]
...
```

**With `--apply`:** same block, followed by:

```
written: skills/<name>/SKILL.md
anchors preserved: <K>/<K>
```

## Errors

- **Skill not found** → abort, print the list of valid skill names
  under `skills/`.
- **Target unreachable within invariants** → abort with
  `compression stuck at −<X>%; loosen --max-loss or compress manually`.
- **Anchor missing after compression** → abort (invariant #2).
- **Uncommitted changes to the SKILL.md without `--force`** → abort.
- **LLM response not valid JSON** → abort, print the raw response.

## Composition

- Run `/octopus:compress-skill <name>` after landing a round of
  edits to a SKILL.md and before committing. The diff plus the
  semantic-risk report are the review surface.
- Pair with RM-024's `_shared/audit-output-format.md` when working
  on audit skills — extract shared conventions first, then compress
  the skill-specific remainder.

## Out of scope

- Compressing `docs/`, `rules/`, or role definitions.
- Multi-skill batch runs. One skill per invocation keeps the diff
  reviewable.
- Restructuring (merging sections, changing heading levels). Only
  text-level compression.
