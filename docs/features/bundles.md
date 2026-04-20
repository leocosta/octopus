# Bundles

Bundles are curated sets of skills + roles + rules + MCP servers + hooks
that express an intent — "I'm a SaaS team with billing", "we produce
marketing content alongside code" — instead of requiring users to pick
each component individually.

## When to use

Whenever you configure a new repo with `octopus setup`. Quick mode
(default) walks you through 4–6 yes/no persona questions that map to
the right bundles. Full mode keeps the per-component multiselect for
power users.

## Enable

`.octopus.yml`:

```yaml
agents:
  - claude

bundles:
  - starter
  - quality-gates
  - cross-stack
  - dotnet-api
```

That's it — no `skills:` list needed. The skills across those four
bundles are delivered automatically when you run `octopus setup`.

## Available bundles (v1)

| Bundle | Category | What you get |
|---|---|---|
| `starter` | foundation | `adr`, `feature-lifecycle`, `context-budget` |
| `quality-gates` | intent | `audit-all` (pulls `security-scan`, `money-review`, `tenant-scope-audit` via `depends_on`) + `backend-specialist` role |
| `growth` | intent | `feature-to-market`, `release-announce` + `social-media` role |
| `docs-discipline` | intent | `plan-backlog-hygiene`, `continuous-learning` + `tech-writer` role |
| `cross-stack` | intent | `cross-stack-contract` + `backend-specialist` + `frontend-specialist` roles |
| `dotnet-api` | stack | `dotnet`, `backend-patterns`, `e2e-testing` + `csharp` rule |
| `node-api` | stack | `backend-patterns`, `e2e-testing` + `typescript` rule |

Pick one `stack` bundle per repo. Intent bundles combine freely.

## Combining with explicit entries

You can declare both `bundles:` and explicit component lists in the
same manifest — explicit entries are **added** to the expanded bundle
contents:

```yaml
bundles:
  - starter
  - quality-gates

# Extras on top of what the bundles provide:
skills:
  - e2e-testing
```

Bundles never remove user selections. To drop an item, switch to Full
mode (`octopus setup`, pick Full at the mode prompt) and reconfigure.

## Authoring a new bundle

Create `bundles/<name>.yml` in the Octopus source root:

```yaml
name: <name>              # required; must match the filename
description: <one line>   # required; shown in the wizard
category: foundation      # foundation | intent | stack
persona_question: "..."   # required for intent/stack; yes/no
persona_default: false    # default answer
skills: [...]
roles: [...]
rules: [...]
mcp: []
hooks: null               # null = don't touch
```

Run `bash tests/test_bundles.sh` to verify the file. Then add a row to
`docs/features/skills.md` noting the bundle membership for any new
skills.

## New-skill convention

Every new skill in Octopus must declare a bundle membership in its
spec's *Context for Agents* section:

```
Bundle: quality-gates (existing) — added to skills list.
```

or, when no existing bundle fits:

```
Bundle: <new-bundle> (proposed) — new bundle file ships with this
skill; see the "Bundle Design" section of this spec.
```

This prevents the catalog from drifting into a pile of loose skills
that users never discover.
