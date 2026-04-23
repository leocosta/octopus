[![Octopus - Centralized AI Agent Configuration](./images/cover.png "Octopus: Multi-repo AI agent configuration")](https://github.com/leocosta/octopus)

---

![Version](https://img.shields.io/badge/version-v1.23.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/shell-bash%204%2B-lightgrey)

# Octopus

Centralized AI agent configuration for multi-repo teams. One source of truth for coding standards, architecture context, and tool-specific settings across all your repositories and AI coding assistants.

Configure once via `.octopus.yml`, run `octopus setup`, and Octopus generates the right configuration for every AI assistant your team uses — Claude Code, GitHub Copilot, OpenAI Codex, Gemini, and OpenCode. Each assistant has different capabilities; Octopus handles these differences automatically through a manifest-driven architecture.

New repos start from **bundles** — curated packages of skills + roles + rules by intent (`starter`, `quality-gates`, `growth`, `cross-stack`, `dotnet-api`, …). The Quick-mode wizard picks the right bundles for you via a few yes/no questions, so you never need to memorize the skill catalog to get a sensible config. Power users keep full control via Full mode or explicit lists in the manifest.

## Installation

**Linux / macOS:**
```bash
curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://github.com/leocosta/octopus/releases/latest/download/install.ps1 | iex
```

**Windows (Git Bash / WSL):** same as Linux/macOS.

To install a specific version:
```bash
curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash -s -- --version v1.23.0
```

After installation, verify with `octopus doctor`.

## Quick Start

```bash
# 1. Install the CLI (see Installation above)

# 2. Run setup — Quick mode asks 4–6 yes/no questions and maps your
#    answers to the right bundles (starter + quality-gates + cross-stack + ...)
octopus setup

# 3. Fill in your .env.octopus with tokens (for MCP servers you selected)

# 4. Commit
git add .octopus.yml .gitignore
git commit -m "chore: add octopus config"
```

Prefer editing a manifest by hand? Copy `.octopus.example.yml` from the
[release](https://github.com/leocosta/octopus/releases/latest) into your
repo as `.octopus.yml`, then run `octopus setup`. For per-component control
(individual skills, roles, mcp) pick Full mode at the wizard prompt — see
[bundles.md](docs/features/bundles.md) for when Full mode pays off.

## Configuration

```yaml
# Which AI agents to configure
# Available: claude, copilot, codex, gemini, opencode
agents:
  - claude
  - copilot

# Bundles — curated packages of skills + roles + rules by intent.
# Available: starter, quality-gates, growth, docs-discipline, cross-stack, dotnet-api, node-api
# Prefer bundles over picking individual skills — run `octopus setup` to let the
# Quick-mode wizard pick bundles for you via a few yes/no persona questions.
bundles:
  - starter
  - quality-gates
  - dotnet-api

# Language rules — coding standards applied to all agents
# Available: common (always included), csharp, typescript, python
# Bundles already set rules (e.g. dotnet-api → csharp); use this for extras.
rules: []

# Skills — optional extras on top of what bundles provide.
# Available: adr, audit-all, backend-patterns, context-budget, continuous-learning, debugging, cross-stack-contract, dotnet, e2e-testing, feature-lifecycle, feature-to-market, implement, money-review, plan-backlog-hygiene, receiving-code-review, release-announce, security-scan, tenant-scope-audit
skills: []

# Hooks — lifecycle automation (Claude Code only)
hooks: true

# Destructive-action guard (default: true when hooks: true).
# Blocks `rm -rf`, `git push --force`, `DROP TABLE`, `DELETE FROM`
# without `WHERE`, and similar. Bypass with
# `# destructive-guard-ok: <reason>` on the command itself.
destructiveGuard: true

# MCP servers — external tool integrations
# Available: notion, github, slack, postgres
mcp:
  - notion
  - github

# Workflow commands — PR, branch, and review automation
# Requires: gh (GitHub CLI) >= 2.0
workflow: true

# GitHub reviewers for PRs
reviewers:
  - github-username

# Roles — agent personas with project context
# Available: product-manager, backend-specialist, frontend-specialist, tech-writer, social-media
roles:
  - product-manager
  - backend-specialist

# Custom project commands — become slash commands with octopus: prefix
commands:
  - name: db-reset
    description: Reset the database
    run: make db-reset

# Language configuration (optional)
language:
  docs: pt-br
  code: en
```

## Features

| Feature | Description | Docs |
|---|---|---|
| **Bundles** | Curated packages of skills + roles + rules by intent — the primary setup path | [bundles.md](docs/features/bundles.md) |
| **Rules** | Language-specific coding standards | [rules.md](docs/features/rules.md) |
| **Skills** | Reusable AI capabilities | [skills.md](docs/features/skills.md) |
| **Hooks** | Lifecycle automation (Claude Code) | [hooks.md](docs/features/hooks.md) |
| **Roles** | Agent personas with project context | [roles.md](docs/features/roles.md) |
| **Knowledge** | Modular domain knowledge | [knowledge.md](docs/features/knowledge.md) |
| **Commands** | Custom slash commands | [commands.md](docs/features/commands.md) |
| **Feature Lifecycle** | RFC/Spec/ADR documentation system | [feature-lifecycle.md](docs/features/feature-lifecycle.md) |
| **MCP Servers** | External tool integrations | [mcp.md](docs/features/mcp.md) |
| **Workflow** | PR and branch automation | [workflow.md](docs/features/workflow.md) |

See also: [Capability Matrix](docs/capability-matrix.md) · [Agent Manifests](docs/agent-manifests.md) · [Project Structure](docs/project-structure.md)

## Updating

```bash
octopus update          # update to latest
octopus update --pin    # update and pin version in lockfile
```

Or via the AI agent (if `workflow: true`):
```
/octopus:update
```

## Requirements

- Bash 4+ (Linux/macOS/WSL) or Git for Windows (PowerShell)
- Python 3 (for JSON merging — MCP injection and hooks)
- `gh` (GitHub CLI) >= 2.0 — only if `workflow: true`

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md).

## Contributing

1. Fork the repo and create a branch: `feat/<description>`, `fix/<description>`
2. Follow patterns in existing agents, rules, and skills
3. Run tests before opening a PR:
   ```bash
   for t in tests/test_*.sh; do bash "$t"; done
   ```
4. Open a PR targeting `main`

See [docs/agent-manifests.md](docs/agent-manifests.md) for how to add new agents, rules, skills, or MCP servers.

## License

MIT — see [LICENSE](./LICENSE) for details.
