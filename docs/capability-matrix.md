# Capability Matrix

How Octopus delivers content to each AI Code Assistant:

| Capability | Claude Code | Copilot | Codex | Gemini | OpenCode |
|---|---|---|---|---|---|
| **Output file** | `.claude/CLAUDE.md` | `.github/copilot-instructions.md` | `AGENTS.md` | `GEMINI.md` | `.opencode/rules.md` |
| **Content mode** | Template | Concatenate | Concatenate | Concatenate | Concatenate |
| **Rules** | Per-file symlinks in `.claude/rules/` | Inlined | Inlined | Inlined | Inlined |
| **Skills** | Symlinked to `.claude/skills/` | Inlined | Inlined | Inlined | Inlined |
| **Hooks** | `settings.json` lifecycle hooks | Quality rules inlined | Quality rules inlined | Quality rules inlined | Quality rules inlined |
| **Commands** | `.claude/commands/` (slash commands) | Inlined section | Inlined section | Inlined section | Inlined section |
| **Feature Lifecycle Commands (`doc-*`)** | `.claude/commands/` (slash commands) | Inlined section | Inlined section | Inlined section | Inlined section |
| **Roles** | `.claude/agents/` (native agents) | Inlined section | Inlined section | Inlined section | Inlined section |
| **Knowledge** | Symlinked to `.claude/knowledge/` | Inlined in roles | Inlined in roles | Inlined in roles | Inlined in roles |
| **MCP** | `settings.json` mcpServers | `.vscode/mcp.json` + `~/.copilot/mcp-config.json` | `codex mcp add` CLI | — | — |

**Template** mode fills placeholders in a template file (Claude's `CLAUDE.md`). **Concatenate** mode assembles a single markdown file from header + core + rules + skills + commands + roles.
