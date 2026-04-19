# Skills

Reusable AI capabilities that provide specialized knowledge.

**Available skills:** `adr`, `backend-patterns`, `context-budget`, `continuous-learning`, `dotnet`, `e2e-testing`, `feature-lifecycle`, `security-scan`

## How it works

1. Add skills to `.octopus.yml`:
   ```yaml
   skills:
     - adr
     - e2e-testing
   ```
2. Run `octopus setup`
3. **Claude Code**: skills are symlinked to `.claude/skills/<name>/` with a `SKILL.md` file each
4. **Other agents**: skill content is appended to the agent's output file

## Adding custom skills

1. Create a directory: `octopus/skills/<name>/`
2. Add a `SKILL.md` file with the skill instructions
3. Add `- <name>` to the `skills:` list in `.octopus.yml`
