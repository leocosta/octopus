<!-- Canonical conventions shared by all pre-merge audit skills
     (money-review, tenant-scope-audit, cross-stack-contract).
     Each audit SKILL.md references this file by path; only
     skill-specific sections (inspection families, config) live
     in the SKILL.md itself. -->

# Audit-skill common conventions

Pre-merge audit skills in Octopus share the following conventions.
When writing or reading an audit skill, assume these apply unless the
SKILL.md explicitly overrides a point.

## Invocation flags

All audit skills accept the same core flags:

- `ref` (positional, optional) — PR (`#123` or URL), branch name, or
  commit SHA. Default: current `HEAD` vs its upstream.
- `--base=<branch>` — base ref for the diff. Default: `main`.
- `--only=<list>` — comma-separated subset of inspection families /
  checks. Family IDs are defined per-skill. Unrecognized values abort
  with a list of valid IDs.
- `--write-report` — also persist the report to
  `docs/reviews/YYYY-MM-DD-<prefix>-<slug>.md`, where `<prefix>` is
  the skill's short name (`money`, `tenant`, `contract`, …) and
  `<slug>` is derived from the branch or PR number (lowercase ASCII,
  non-alphanumeric runs collapsed to `-`, max 40 chars).

Additional per-skill flags (e.g. `--stacks` in cross-stack-contract)
are documented in the SKILL.md.

## Override-file cascade

Each skill reads pattern / provider overrides in this order (first
match wins):

1. `docs/<skill-name>/patterns.md` (canonical)
2. `docs/<SKILL_NAME>_PATTERNS.md` (uppercase compat)
3. `skills/<skill-name>/templates/patterns.md` (embedded default)

Overrides **append** to the defaults — they never replace them. A
malformed override emits a warning, is ignored, and the skill
continues with defaults.

## Output — severity format

The default (chat) output is one markdown block with three headings,
each listing findings for that severity:

```
## 🚫 Block (N)
- <ID> **<family>** (<confidence>, when applicable): <description>
  [<file>:<line>]

## ⚠ Warn (N)
- ...

## ℹ Info (N)
- ...
```

- `<ID>` is the per-skill finding ID (`T1`, `C3`, etc.).
- `<family>` matches the `--only` token.
- `<confidence>` (`high` / `medium` / `low`) is included when the
  skill uses heuristic matching.
- Always end with a trailer line:
  `<skill-name>: N block, N warn, N info` (skills may append
  context in parentheses, e.g. the tenant-scope config).

## `--write-report` frontmatter

When `--write-report` is passed, the same markdown is persisted with a
frontmatter block:

```yaml
---
ref: <branch-or-pr>
base: <base-branch>
generated_by: octopus:<skill-name>
generated_at: YYYY-MM-DD
summary: "N block, N warn, N info"
---
```

Skills may add extra fields (e.g. `stacks:`, `config:`) after the
mandatory ones.

## Common errors

All audit skills handle these conditions uniformly:

- **Not in a git repo** → abort.
- **Base branch not found** → abort with
  `run 'git fetch' or pass --base=<branch>`.
- **No relevant files in diff** → print
  `no <domain> changes detected` and exit 0 with
  `<skill-name>: 0 block, 0 warn, 0 info`.
- **Malformed manifest / override** → warn, fall back to defaults,
  continue.
- **Unrecognized `--only` value** → abort, list valid IDs.

Per-skill errors (e.g. cross-stack-contract's "only one stack
detected") are documented in the SKILL.md.

## Composition

All audit skills emit the same three-heading severity format and
frontmatter shape. Their reports concatenate into a single PR comment
without extra formatting work. `audit-all` runs them in parallel and
merges the output by severity.

Findings are guidance, not a gate — `🚫 Block` signals that a
reviewer should require changes before merge; `⚠ Warn` and `ℹ Info`
support discussion.
