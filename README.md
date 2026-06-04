<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./images/cover-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="./images/cover-light.png">
  <img alt="Octopus — Centralized AI Agent Configuration" src="./images/cover-dark.png">
</picture>

---

![Version](https://img.shields.io/badge/version-v1.78.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/shell-bash%204%2B-lightgrey)

# Octopus

**One source of truth for AI coding agents across every repo your team owns.**

Configure once via `.octopus.yml`, run `octopus setup`, and Octopus generates the right configuration for every AI assistant you use — Claude Code, GitHub Copilot, OpenAI Codex, Gemini, OpenCode. Each assistant has different capabilities; Octopus handles the differences through a manifest-driven architecture so your standards, context, and tooling stay consistent.

New repos start from **bundles** — curated packages of skills, roles, and rules by intent (`starter`, `saas-quality`, `fullstack`, `dotnet-api`, …). A short Quick-mode wizard picks the right bundles for you. Power users keep full control via Full mode or explicit lists in the manifest.

## What you get

- **Bundles & skills** — reusable AI capabilities mapped to real workflows (audits, doc lifecycle, PR review, launches)
- **Roles** — specialized agent personas (`@architect`, `@backend-developer`, `@product-manager`, …) with project context
- **Hooks & guards** — lifecycle automation and a destructive-action guard (blocks `rm -rf`, `git push --force`, `DROP TABLE` without `WHERE`, …)
- **`octopus control`** — terminal dashboard to run and monitor multiple agents locally, no browser, no cloud
- **`octopus run`** — drive a feature from description → spec → plan → parallel agents → open PR
- **`octopus ask`** — delegate a task to a specific role and stream its output live
- **MCP & workflow** — first-class integrations for Notion, GitHub, Slack, Postgres, and PR/branch automation

## Install

```bash
# Linux / macOS / WSL
curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash

# Windows (PowerShell)
irm https://github.com/leocosta/octopus/releases/latest/download/install.ps1 | iex
```

Verify with `octopus doctor`, then in your repo:

```bash
octopus setup        # answers 4–6 yes/no questions, writes .octopus.yml
git add .octopus.yml .gitignore
git commit -m "chore: add octopus config"
```

## Documentation

The full handbook — concepts, bundles, skills, roles, hooks, commands, and the `control` / `run` / `ask` deep dives — lives at:

### 👉 **[leocosta.github.io/octopus](https://leocosta.github.io/octopus/)**

Start here:

- [What is Octopus](https://leocosta.github.io/octopus/get-started/what-is-octopus/) — the problem it solves
- [Mental Model](https://leocosta.github.io/octopus/get-started/mental-model/) — how the pieces fit together
- [Installation](https://leocosta.github.io/octopus/get-started/install/) · [Quick Start](https://leocosta.github.io/octopus/get-started/quickstart/)

## Requirements

- Bash 4+ (Linux/macOS/WSL) or Git for Windows (PowerShell)
- Python 3 (JSON merging — MCP injection and hooks)
- `gh` (GitHub CLI) ≥ 2.0 — only if `workflow: true`

## Contributing

1. Fork and branch: `feat/<description>` or `fix/<description>`
2. Follow patterns in existing bundles, skills, and roles
3. Run tests: `for t in tests/test_*.sh; do bash "$t"; done`
4. Open a PR targeting `main`

See the [Architecture](https://leocosta.github.io/octopus/architecture/) section of the docs for how to add new agents, rules, skills, or MCP servers.

## License

MIT — see [LICENSE](./LICENSE).
