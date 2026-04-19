# Knowledge

Modular domain knowledge that agents can load on demand — confirmed facts, hypotheses under investigation, and promoted rules. Each domain lives in its own folder under `knowledge/` and follows a structured format.

## How it works

1. Add `knowledge:` to `.octopus.yml` (three formats supported):
   ```yaml
   # Format A: auto-discover all folders in knowledge/ (not prefixed with _)
   knowledge: true

   # Format B: explicit module list
   knowledge:
     - domain
     - architecture
     - authentication

   # Format C: full config with per-role mapping
   knowledge:
     modules:
       - domain
       - architecture
       - pricing
       - retention
       - analytics
     roles:
       backend-specialist:
         - domain
         - architecture
       product-manager:
         - domain
         - pricing
         - retention
         - analytics
   ```
2. Run `octopus setup`
3. **Claude Code**: `knowledge/` is symlinked to `.claude/knowledge/` — agents load modules on demand
4. **Other agents**: knowledge content is assembled per-role and inlined into the `{{PROJECT_CONTEXT}}` placeholder

## Custom directory

By default, modules live in `knowledge/`. Use `knowledge_dir:` to change the location:
```yaml
knowledge_dir: docs/ai   # modules will be read from docs/ai/ instead of knowledge/
knowledge: true
```

## Auto-generated index

When knowledge is enabled, `setup.sh` creates `<knowledge_dir>/INDEX.md` — a routing table listing every active module with file counts. Agents consult this first to find relevant domain context.

## Creating a knowledge module

```bash
cp -r octopus/knowledge/_template knowledge/<domain>
# Edit the files inside knowledge/<domain>/
```

Each module contains:
- `knowledge.md` — confirmed facts and anti-patterns
- `hypotheses.md` — under-investigation observations (promoted to rules after 5 confirmations)
- `rules.md` — auto-applied rules promoted from hypotheses
