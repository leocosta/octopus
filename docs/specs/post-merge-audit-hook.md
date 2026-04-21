# Spec: Post-Merge Audit Hook

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-21 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-029 |

## Problem Statement

Octopus ships four pre-merge audit skills (`money-review`,
`tenant-scope-audit`, `cross-stack-contract`, `security-scan`) plus
the `audit-all` composer, but reviewers and authors have to
remember to run them. In practice they run sporadically — and
the most valuable signals (money-logic drift, missing tenant
filters, cross-stack contract breakage) are precisely the ones
that benefit from being automatic on a hot PR.

## Goals

- A git hook (post-merge or post-commit, TBD in design) that looks
  at the diff of the incoming change, maps touched files +
  keywords to the relevant audits, and surfaces the list as a
  gentle suggestion: "this change touched billing code; consider
  running `/octopus:money-review`".
- Zero-config for the common case: the hook activates for repos
  that have `workflow: true` in `.octopus.yml` and have at least
  one of the audit skills installed.
- Opt-out per repo via a manifest key; opt-out per invocation via
  an env var.
- No execution of audits in the hook itself — just suggestion.
  Audits remain agent-driven.

## Non-Goals

- Running audits automatically in the hook (too slow / too noisy).
- Blocking the merge. The hook is advisory.
- Posting comments on a GitHub PR. Out of scope for this spec;
  could be a follow-up that reuses the same mapping.
- Replacing `/octopus:audit-all` as the pre-merge composer.

## Design

### Overview

A `pre-push` git hook that reads the diff of the commits about
to be pushed, maps touched files and keywords to the relevant
Octopus audit skills (`money-review`, `tenant-scope-audit`,
`cross-stack-contract`, `security-scan`), and prints a short
list of suggestions before returning exit 0 (advisory only —
never blocks the push).

The hook is installed by `octopus setup` when:

- `.octopus.yml` has `workflow: true` (the existing switch for
  PR/branch commands), AND
- at least one of the audit skills is present in the generated
  config.

The hook body is a thin bash script under
`hooks/git/pre-push-audit-suggest.sh` that shells out to a
shared mapping library (`cli/lib/audit-map.sh`) so the same
logic can later power a PR-comment bot (explicitly out of
scope here).

Opt-outs:

- Per-repo: `postMergeAuditHook: false` in `.octopus.yml`
  disables installation. Name kept for roadmap continuity even
  though the hook is `pre-push` — the roadmap entry says
  "post-merge or post-commit, TBD in design".
- Per-invocation: `OCTOPUS_SKIP_AUDIT_HOOK=1 git push` bypasses
  the hook's suggestion output.

The hook is advisory only. It never runs the audits themselves;
it never blocks the push; it never pings the network.

### Detailed Design

**Components**

| File | Role |
|---|---|
| `hooks/git/pre-push-audit-suggest.sh` | The hook body. Reads `$OCTOPUS_SKIP_AUDIT_HOOK`, computes the push diff, dispatches to the map library, prints suggestions. Exits 0 unconditionally. |
| `cli/lib/audit-map.sh` | Pure function library. Given a unified diff on stdin, emits the set of audit names (`money-review`, `tenant-scope-audit`, `cross-stack-contract`, `security-scan`) whose triggers fired. |
| `setup.sh` (modification) | Installs the hook into `.git/hooks/pre-push` (or `core.hooksPath` when set) when `workflow: true` AND `postMergeAuditHook` is not `false`. |
| `cli/lib/parse_octopus_yml` (existing) | Reads the new `postMergeAuditHook:` key. Default `true`. |

**Hook flow (`pre-push-audit-suggest.sh`)**

1. If `$OCTOPUS_SKIP_AUDIT_HOOK` is set → exit 0 silently.
2. Compute the diff of commits about to be pushed:
   ```bash
   # git passes <local-ref> <local-sha> <remote-ref> <remote-sha> on stdin
   while read local_ref local_sha remote_ref remote_sha; do
     range="${remote_sha}..${local_sha}"
   done
   diff=$(git diff "$range" 2>/dev/null)
   ```
   For new branches (`remote_sha` is 40 zeros), use
   `main..local_sha` as the range.
3. Pipe `$diff` into `audit-map.sh`. Collect the set of matched
   audits.
4. If the set is empty → exit 0 silently.
5. Otherwise print a blocklet:
   ```
   ┌─ Octopus — audit suggestions ─────────────────────────────┐
   │ This push touches code typically audited by:              │
   │   • /octopus:money-review   (billing / payment tokens)    │
   │   • /octopus:security-scan  (secret / credential tokens)  │
   │ Run them in your agent before merging if applicable.      │
   │ Skip: OCTOPUS_SKIP_AUDIT_HOOK=1 git push                  │
   └───────────────────────────────────────────────────────────┘
   ```
6. Exit 0. Never block the push.

**Mapping logic (`cli/lib/audit-map.sh`)**

For each known audit, resolve its patterns via the existing
cascade already used by audit skills:

1. `docs/<audit-name>/patterns.md` (canonical)
2. `docs/<AUDIT_NAME>_PATTERNS.md` (uppercase compat)
3. `skills/<audit-name>/templates/patterns.md` (embedded
   default)

Parse the resolved `patterns.md` for two kinds of signals:

- `path_tokens:` — substrings tested against the diff's `+++`
  and `---` file paths.
- `content_regex:` — regexes tested against added / removed
  lines (`+` / `-` prefixes).

An audit matches when **any** of its path tokens OR content
regexes hit the diff. Emit `<audit-name>` on its own line on
stdout. Order: `security-scan`, `money-review`,
`tenant-scope-audit`, `cross-stack-contract` (criticality, then
alphabetical).

**Cross-stack special case:** `cross-stack-contract` doesn't
need a `patterns.md` — it fires when the diff touches paths
belonging to two or more stacks declared in the manifest's
`stacks:` map. Implemented as a dedicated helper inside
`audit-map.sh` rather than via pattern lookup.

**Install / uninstall (`setup.sh` modifications)**

During setup, after the existing Claude Code hook injection:

```bash
if [[ "$OCTOPUS_WORKFLOW" == "true" \
   && "$OCTOPUS_POST_MERGE_AUDIT_HOOK" != "false" \
   && _has_any_audit_skill ]]; then
  target="$(git_hooks_path)/pre-push"
  if [[ -f "$target" && ! $(grep -l "octopus:pre-push-audit-suggest" "$target") ]]; then
    warn "Existing pre-push hook detected; chaining Octopus suggestions."
    # append a line to chain call after existing body
  else
    install "$OCTOPUS_DIR/hooks/git/pre-push-audit-suggest.sh" "$target"
    chmod +x "$target"
  fi
fi
```

An existing pre-push hook is preserved; the Octopus suggester
is appended via chain mode (source the existing body first,
then run the suggester).

**Opt-out via env var** (`OCTOPUS_SKIP_AUDIT_HOOK=1`): handled
in the hook body, not at install time. User keeps the hook
installed but bypasses the output for a given push.

### Migration / Backward Compatibility

- **New manifest key `postMergeAuditHook:`** — default `true`.
  Repos that already have `workflow: true` and at least one
  audit skill installed get the hook automatically on their
  next `octopus update && octopus setup`. Users who want the
  old behaviour declare `postMergeAuditHook: false` before
  running setup.
- **Existing `.git/hooks/pre-push`** — preserved via chain
  mode (see Detailed Design). Documented in the README's
  Hooks section; no manual action required.
- **`.octopus.example.yml`** — a new commented line is added
  under the hooks configuration block documenting the opt-out.
- **No auto-migration tooling.** The field is additive; its
  default value activates the behaviour on next setup.
  Documented in the CHANGELOG as a new-feature entry (minor
  bump).

## Implementation Plan

1. **Document the `patterns.md` mini-schema** and migrate the
   existing audit `patterns.md` files
   (`docs/money-review/`, `docs/tenant-scope-audit/`,
   `docs/security-scan/`, `skills/*/templates/patterns.md`)
   to it. Two headings — `## Path tokens` and
   `## Content regex` — with bullet lists. Isolated refactor
   PR, no behaviour change.
2. **Create `cli/lib/audit-map.sh`.** Pure function library:
   `audit_map_match <audit-name> <diff-file>` returns 0/1,
   `audit_map_all <diff-file>` emits matched names line by
   line. Uses the `patterns.md` cascade + word-bound regexes.
   Special cross-stack helper reading `.octopus.yml` `stacks:`.
   Depends on Step 1.
3. **Create `tests/test_audit_map.sh`.** Fixture diffs per
   audit (a billing.cs diff → expects `money-review`; a diff
   touching `api/` + `app/` → expects `cross-stack-contract`;
   a diff adding `sk-ABC123` → expects `security-scan`; a
   benign README diff → expects empty). Malformed
   `patterns.md` fixture → skip that audit, warn once.
   Depends on Step 2.
4. **Create `hooks/git/pre-push-audit-suggest.sh`.** Reads
   stdin (git ref list), computes diff range, pipes into
   `audit_map_all`, prints the blocklet. Env-var skip,
   exit 0 unconditionally. Depends on Step 2.
5. **Add `postMergeAuditHook` parsing + default in
   `setup.sh`.** Reads the manifest key (default `true`).
   Add to `.octopus.example.yml` with the commented opt-out.
   Extend `deliver_hooks` (or add `deliver_git_hooks`) with
   the install logic, including chain mode when a `pre-push`
   already exists. Depends on Step 4.
6. **Create `tests/test_post_merge_audit_hook.sh`.** End-to-end
   install test: minimal fixture repo with `workflow: true`
   and one audit skill → `octopus setup` installs the hook →
   the hook is executable and contains the chain shim. Second
   case: repo with `postMergeAuditHook: false` → hook not
   installed. Third case: pre-existing `pre-push` → chained,
   prior body preserved. Depends on Step 5.
7. **Move RM-029 from Backlog to Completed** in
   `docs/roadmap.md`; flip the spec's `Status` to
   `Implemented (<date>)`; add a CHANGELOG entry under the
   next unreleased section.

## Context for Agents

**Knowledge modules**: N/A.
**Implementing roles**: backend-specialist (bash),
tech-writer (for the `patterns.md` schema doc).
**Related ADRs**: none yet; the `patterns.md` mini-schema
merits an ADR — flag as a follow-up.
**Skills needed**: `adr`, `feature-lifecycle`,
`security-scan`, `money-review`, `tenant-scope-audit`,
`cross-stack-contract`, `audit-all`.
**Bundle**: N/A — hook under the existing `hooks:` setting,
not a new skill.

**Constraints**:
- Pure bash, no external dependencies beyond `git` itself.
- Idempotent install: re-running `octopus setup` must not
  duplicate the chain shim in `pre-push`.
- Must be fast: ≤ 500 ms on a medium diff.
- Must respect `destructiveGuard` / `hooks:` opt-outs that
  already exist in the manifest schema.
- Never writes files outside `.git/hooks/` at install time;
  never runs audits or posts to any network at invocation
  time.

## Testing Strategy

- **Unit tests** in `tests/test_audit_map.sh` (step 3 of the
  plan): fixture diffs covering each audit, empty-set diff,
  malformed `patterns.md` graceful failure, and
  cross-stack-contract manifest-driven path matching.
- **Install tests** in `tests/test_post_merge_audit_hook.sh`
  (step 6): minimal fixture repos exercising the three
  install paths (fresh, opt-out, chain onto existing hook).
- **Performance check** during dog-food: time the hook on a
  medium diff (≈ 200 lines changed across mixed paths).
  Accept if under 500 ms on a dev laptop; fail the task
  otherwise and optimise the matching loop.
- **No network, no live git push** — tests use local-only
  refs and `git hash-object` fixtures.

## Risks

- **Push latency.** `git push` now runs the hook. Even though
  it's non-blocking, any perceived wait hurts the flow.
  Budget: ≤ 500 ms on a typical diff. Mitigation: diff parsing
  in pure bash with early-exit when no path token matches —
  content regexes only run against files that already passed
  the path filter.
- **Fragile chain mode.** Repos that already carry a
  `pre-push` hook (Husky, pre-commit, etc.) must keep working.
  Mitigation: detect the existing shebang, append the Octopus
  call at the end, preserve the prior exit code so an
  upstream failure still blocks the push.
- **Pattern-parser compatibility with existing `patterns.md`.**
  Each audit skill ships its own `patterns.md`; the format is
  not currently documented as a parseable schema. Mitigation:
  define a mini-schema (`## Path tokens`, `## Content regex`
  headings) and migrate the current patterns in a separate
  task. `audit-map.sh` fails gracefully on malformed input —
  it logs a single line to stderr and skips that audit rather
  than aborting the push.
- **False positives.** A regex like `sk-` also matches
  `task-runner`. Noisy suggestions train users to ignore the
  hook. Mitigation: use word boundaries (`\bsk-\w+`),
  deduplicate suggestions (cap 4), and hard-order the output
  so the most-likely-relevant audit comes first.

## Changelog

- **2026-04-21** — Initial draft
- **2026-04-21** — Design session completed (dog-food round 2 of `/octopus:doc-design`)
