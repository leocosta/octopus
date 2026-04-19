# Rules

Language-specific coding standards applied to all agents.

**Available rules:** `common` (always included), `csharp`, `typescript`, `python`

## How it works

1. Add languages to `.octopus.yml`:
   ```yaml
   rules:
     - csharp
     - typescript
   ```
2. Run `octopus setup`
3. **Claude Code**: rules are symlinked to `.claude/rules/<language>/` — Claude reads them as native rule files
4. **Other agents**: all rule markdown files are appended to the agent's output file

## What's included

- `common/` — coding style, patterns, security, testing, quality checklist (always included)
- `csharp/` — API patterns, architecture, data access, error handling, naming, testing
- `typescript/` — naming, Next.js patterns, React patterns, state management, testing, tooling
- `python/` — architecture, naming, testing, tooling, typing

## Adding custom rules

1. Create a directory: `octopus/rules/<name>/`
2. Add `.md` files inside it
3. Add `- <name>` to the `rules:` list in `.octopus.yml`

## Project-level overrides

Create `.octopus/rules/common/language.local.md` in your repo root. `setup.sh` distributes it to all configured agents automatically — no duplication across agent directories. The `.local.md` convention extends to any rule file under `.octopus/rules/`.
