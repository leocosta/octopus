# MCP Servers

External tool integrations (Notion, GitHub, Slack, PostgreSQL) configured from a single source.

**Available servers:** `notion`, `github`, `slack`, `postgres`

## How it works

1. Add servers to `.octopus.yml`:
   ```yaml
   mcp:
     - notion
     - github
   ```
2. Add required environment variables to `.env.octopus`:
   - `notion` — uses OAuth (no env vars needed)
   - `github` — `GITHUB_TOKEN`
   - `slack` — `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID`
   - `postgres` — `DATABASE_URL`
3. Run `octopus setup` (or `./octopus/setup.sh`)
4. Delivery varies per agent (see [Capability Matrix](../capability-matrix.md)):
   - **Claude Code**: merged into `.claude/settings.json` under `mcpServers`
   - **Copilot**: `.vscode/mcp.json` + `~/.copilot/mcp-config.json`
   - **Codex**: `codex mcp add` CLI commands

## Adding custom MCP servers

1. Create `octopus/mcp/<name>.json` following the template in `mcp/_template.json`
2. Use `${VAR_NAME}` for secrets — they'll be read from `.env.octopus`
3. Add `- <name>` to the `mcp:` list in `.octopus.yml`

## Social publishing note

For social publishing workflows, prefer official platform APIs for production publishing. Community MCP servers can still be useful, but they should be treated as optional adapters and reviewed for security, maintenance, and policy compliance before adoption.

This repository includes a direct X helper script (`scripts/x_post.py`) rather than a built-in social MCP server. The helper uses `.env.octopus` credentials and is intended for approval-gated publishing tests and local automation.
