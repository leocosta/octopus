# Spec: `/octopus:compress-skill`

**Status:** Draft
**Roadmap:** RM-023
**Dependencies:** none (complements RM-022 and RM-024 but ships independently)

## Problem

Skill authors tend to over-document. `SKILL.md` files accumulate
verbose prose, redundant examples, long tables, and filler
connectives. Every extra line lands in the context window of every
session that loads the skill. RM-024 removed cross-skill duplication;
RM-023 targets **in-skill verbosity** — text that can be shortened
without losing meaning.

Target: −25% bytes per skill without regressing tests or behaviour.

## Non-goals

- Automatic application. All compression is diff-reviewed by a human.
- Rewriting structure (section order, heading levels, table-vs-list).
  Compression preserves structure; restructuring is a separate task.
- Touching code, templates, tests, or the shared `_shared/` fragments.

## UX

```
/octopus:compress-skill <skill-name> [--apply] [--target=<pct>] [--max-loss=<pct>]
```

- `<skill-name>` — required; must match a directory under `skills/`.
- `--apply` — write the compressed `SKILL.md` back. Without this flag
  the command prints the diff and exits without modifying files.
- `--target=<pct>` — desired compression ratio. Default: `25`.
- `--max-loss=<pct>` — abort if the compression LLM pass reports more
  than this fraction of content as "potentially semantic-changing".
  Default: `5`.

Flow:

1. Read `skills/<name>/SKILL.md`.
2. Read the skill's tests (e.g. `tests/test_<name>.sh`) to extract
   **literal anchors** — strings the tests `grep` for. These strings
   MUST survive compression.
3. Run a compression pass (deterministic heuristics first, LLM
   second — see below). Anchors are passed in as a "do not remove"
   allow-list.
4. Produce a side-by-side diff with a summary:
   `before: N lines / M bytes; after: N' / M'; Δ: −X%`.
5. Print a **semantic-risk report** — a bulleted list of changes the
   compressor flagged as possibly altering intent (e.g. dropped
   caveats, merged sentences).
6. If `--apply`, write the new file. Otherwise exit 0 after printing.

## Compression heuristics (deterministic pass)

Run before any LLM call:

- Collapse consecutive blank lines to one.
- Trim trailing whitespace.
- Strip bullet prefixes that duplicate the preceding sentence (e.g.
  "This skill does X. - Does X." → keep the sentence).
- Remove "This section describes…" / "As mentioned above…" meta
  prose matching a fixed regex list.
- Collapse `e.g.` example lists longer than 3 items to the first 3
  + "…".

## LLM pass

Only runs when the deterministic pass did not hit the target.

- Model: whichever Claude model the host runtime is using; the
  prompt lives at `skills/compress-skill/templates/prompt.md`.
- Input: remaining `SKILL.md` text + the test-anchor allow-list +
  the target ratio.
- Output: compressed text + a JSON block listing every passage the
  model deleted / merged with a one-line justification.
- Mandatory invariants (enforced after the LLM returns):
  - Frontmatter is byte-identical.
  - All anchor strings are present.
  - No section heading was removed or renamed.
  - No code block was modified.

If any invariant fails, the command aborts and prints the failing
invariant. No file is written.

## Output

Chat (no `--apply`):

```
## Compression preview — skills/money-review/SKILL.md

before: 197 lines / 7.1 KB
after:  148 lines / 5.3 KB
Δ:      −25% bytes, −25% lines

## Diff
<unified diff>

## Semantic-risk report
- merged two sentences in "### T3 tests" — intent preserved.
- dropped one example in "## Invocation" — covered by `--only` list.
```

With `--apply`: same output + `written: skills/money-review/SKILL.md`.

## Errors

- **Skill not found** → abort with a list of valid skill names.
- **Target not achievable within invariants** → abort with
  "compression stuck at −N%; loosen `--max-loss` or compress
  manually".
- **Anchor missing in compressed output** → abort (LLM invariant
  failure), print the missing anchor.
- **Non-clean git tree for the SKILL.md** → warn and require
  `--force`; otherwise the review diff would be polluted.

## Bundle

Adds to the **`docs-discipline`** bundle. The bundle already hosts
meta-tools for documentation quality (`plan-backlog-hygiene`,
`continuous-learning`); compressing skill documentation fits the same
audience — teams that actively maintain written artefacts.

No new bundle is proposed.

## Tests (`tests/test_compress_skill.sh`)

1. SKILL.md exists with valid frontmatter + `## Invocation` section.
2. Slash command `commands/compress-skill.md` exists.
3. Bundle `bundles/docs-discipline.yml` lists `compress-skill`.
4. Dry-run on a fixture skill (`tests/fixtures/dummy-skill/SKILL.md`)
   produces a diff and does NOT modify the file.
5. `--apply` on the fixture writes a smaller file and preserves
   every anchor from a fixture test file.
6. Invariant failure (missing anchor injected into a mock LLM
   response) aborts with non-zero exit.

Tests 4–6 mock the LLM via a fixture file rather than calling a real
model.

## Out of scope

- Compressing `docs/` files, `rules/`, or role definitions.
- Multi-skill batch compression. Users run the command per skill to
  keep diffs reviewable.
- Auto-running on pre-commit. Compression is a deliberate act.

## Open questions

- Should the LLM pass be skippable via `--heuristics-only`? Useful in
  CI or offline contexts. Likely yes; decide during implementation.
- Where does the mock-LLM fixture live — `tests/fixtures/` or inline
  inside `tests/test_compress_skill.sh`? Prefer the fixtures dir to
  keep the test readable.
