# Agent Manifests

Each agent in `octopus/agents/<name>/` has a `manifest.yml` that declares what the tool supports natively:

```yaml
name: claude
output: .claude/CLAUDE.md
content_mode: template          # "template" or "concatenate"

capabilities:
  native_rules: true            # Can use symlinked rule files
  native_skills: true           # Can use symlinked skill files
  native_hooks: true            # Supports lifecycle hooks
  native_commands: true         # Supports individual command files
  native_agents: true           # Supports individual agent/role files
  native_mcp: true              # Supports MCP server configuration

delivery:
  rules:
    method: symlink             # How to deliver rules when native
    target: .claude/rules/      # Where to put them
  # ... (one entry per capability)

gitignore_extra:                # Additional paths for .gitignore
  - .claude/settings.json
  - .claude/commands/
```

`setup.sh` reads the manifest and routes content accordingly — no hardcoded agent logic.

## Adding a new agent

1. Create `octopus/agents/<name>/`
2. Add `manifest.yml` declaring capabilities (copy from an existing agent and adjust)
3. Add `header.md` with tool-specific instructions (limitations, format preferences)
4. Add `- <name>` to `.octopus.yml` agents list
5. Run `octopus setup`

No changes to `setup.sh` needed — the manifest drives all behavior.
