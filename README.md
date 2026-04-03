[![Octopus - Centralized AI Agent Configuration](./images/cover.png "Octopus: Multi-repo AI agent configuration")](https://github.com/leocosta/octopus)

---

![Version](https://img.shields.io/badge/version-v0.4.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/shell-bash%204%2B-lightgrey)

# Octopus

Centralized AI agent configuration for multi-repo teams. One source of truth for coding standards, architecture context, and tool-specific settings across all your repositories and AI coding assistants.

## Table of Contents

- [What is Octopus](#what-is-octopus)
- [Capability Matrix](#capability-matrix)
- [Quick Start](#quick-start)
- [Configuration (.octopus.yml)](#configuration-octopusyml)
- [Features](#features)
  - [Rules](#rules)
  - [Skills](#skills)
  - [Hooks](#hooks)
  - [Roles](#roles)
  - [Knowledge](#knowledge)
  - [Commands](#commands)
  - [Feature Lifecycle](#feature-lifecycle)
  - [MCP Servers](#mcp-servers)
  - [Workflow](#workflow)
- [Agent Manifests](#agent-manifests)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Requirements](#requirements)
- [License](#license)

## What is Octopus

Octopus is a framework that lives as a git submodule in your repositories. You configure it once via `.octopus.yml`, run `setup.sh`, and it generates the right configuration files for every AI Code Assistant your team uses — Claude Code, GitHub Copilot, OpenAI Codex, Antigravity, and OpenCode.

Each assistant has different capabilities (some support native rules, others need everything in a single markdown file). Octopus handles these differences automatically through a **manifest-driven architecture** — you write rules, skills, and hooks once, and Octopus delivers them in the format each tool understands.

## Capability Matrix

How Octopus delivers content to each Code Assistant:

| Capability | Claude Code | Copilot | Codex | Antigravity | OpenCode |
|---|---|---|---|---|---|
| **Output file** | `.claude/CLAUDE.md` | `.github/copilot-instructions.md` | `AGENTS.md` | `ANTIGRAVITY.md` | `.opencode/rules.md` |
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

## Quick Start

### Add to an existing repo

```bash
# 1. Add octopus as a submodule
git submodule add git@github.com:leocosta/octopus.git octopus
git submodule update --init

# 2. Configure
cp octopus/.octopus.example.yml .octopus.yml
# Edit .octopus.yml — choose your languages, agents, and features

# 3. Run setup
./octopus/setup.sh

# 4. Fill in your .env.octopus with personal tokens (for MCP servers)

# 5. Commit
git add .octopus.yml octopus .gitignore
git commit -m "chore: add octopus config"
```

### Update to a new version

If you have `workflow: true` enabled, ask your AI agent:
```
/octopus:update
```
The agent will show available versions, confirm with you, and handle the checkout, setup re-run, and commit.

Or update manually:
```bash
cd octopus && git fetch --tags && git checkout v0.4.0 && cd ..
./octopus/setup.sh
git add octopus && git commit -m "chore: update octopus to v0.4.0"
```

## Configuration (.octopus.yml)

```yaml
# Language rules — coding standards applied to all agents
# Available: common (always included), csharp, typescript, python
rules:
  - csharp
  - typescript

# Skills — reusable AI capabilities
# Available: adr, backend-patterns, context-budget, continuous-learning, dotnet, e2e-testing, feature-lifecycle, security-scan
skills:
  - adr
  - e2e-testing

# Hooks — lifecycle automation (Claude Code only)
# Options: true (enable all), false (disable)
# Disable specific hooks via env: OCTOPUS_DISABLED_HOOKS=hook-id-1,hook-id-2
hooks: true

# Which AI agents to configure
# Available: claude, copilot, codex, antigravity, opencode
agents:
  - claude
  - copilot

# MCP servers — external tool integrations
# Available: notion, github, slack, postgres (or any .json file in mcp/)
mcp:
  - notion
  - github

# Workflow commands — PR, branch, and review automation
# Requires: gh (GitHub CLI) >= 2.0 installed and authenticated
workflow: true

# GitHub reviewers for PRs
reviewers:
  - github-username

# Roles — agent personas with project context
# Available: product-manager, backend-specialist, frontend-specialist, tech-writer
# Context is provided via knowledge modules (see knowledge: config below)
roles:
  - product-manager
  - backend-specialist

# Custom project commands — become slash commands with octopus: prefix
commands:
  - name: db-reset
    description: Reset the database
    run: make db-reset
  - name: api-start
    description: Start the API container
    run: make api-start
```

## Features

### Rules

Language-specific coding standards applied to all agents.

**Available rules:** `common` (always included), `csharp`, `typescript`, `python`

**How it works:**
1. Add languages to `.octopus.yml`:
   ```yaml
   rules:
     - csharp
     - typescript
   ```
2. Run `./octopus/setup.sh`
3. **Claude Code**: rules are symlinked to `.claude/rules/<language>/` — Claude reads them as native rule files
4. **Other agents**: all rule markdown files are appended to the agent's output file

**What's included:**
- `common/` — coding style, patterns, security, testing, quality checklist (always included)
- `csharp/` — API patterns, architecture, data access, error handling, naming, testing
- `typescript/` — naming, Next.js patterns, React patterns, state management, testing, tooling
- `python/` — architecture, naming, testing, tooling, typing

**Adding custom rules:**
1. Create a directory: `octopus/rules/<name>/`
2. Add `.md` files inside it
3. Add `- <name>` to the `rules:` list in `.octopus.yml`

### Language Configuration

By default, the AI detects the project's language from existing docs, git history, and locales/. To configure language explicitly, add `language:` to `.octopus.yml`:

```yaml
# Short form (applies to all artifact types):
language: en

# Per-scope form:
language:
  docs: pt-br    # specs, ADRs, commits, PR descriptions
  code: en       # code comments (identifiers are always English)
  ui: pt-br      # user-facing messages and UI copy
```

**Project-level overrides**: create `.octopus/rules/common/language.local.md` in your repo root. `setup.sh` distributes it to all configured agents automatically — no duplication across agent directories. The `.local.md` convention extends to any rule file under `.octopus/rules/`.

### Skills

Reusable AI capabilities that provide specialized knowledge.

**Available skills:** `adr`, `backend-patterns`, `context-budget`, `continuous-learning`, `dotnet`, `e2e-testing`, `feature-lifecycle`, `security-scan`

**How it works:**
1. Add skills to `.octopus.yml`:
   ```yaml
   skills:
     - adr
     - e2e-testing
   ```
2. Run `./octopus/setup.sh`
3. **Claude Code**: skills are symlinked to `.claude/skills/<name>/` with a `SKILL.md` file each
4. **Other agents**: skill content is appended to the agent's output file

**Adding custom skills:**
1. Create a directory: `octopus/skills/<name>/`
2. Add a `SKILL.md` file with the skill instructions
3. Add `- <name>` to the `skills:` list in `.octopus.yml`

### Hooks

Lifecycle hooks that automate quality enforcement for Claude Code. Other agents receive equivalent quality rules inlined from `rules/common/quality.md`.

**Available hooks:**

| Hook | Phase | What it does |
|---|---|---|
| `block-no-verify` | PreToolUse | Blocks `--no-verify` in git commands |
| `detect-secrets` | PreToolUse | Warns about hardcoded secrets |
| `git-push-reminder` | PreToolUse | Reminds to review before pushing |
| `format-check` | PreToolUse | Checks formatting on file writes |
| `auto-format` | PostToolUse | Auto-formats edited files |
| `typecheck` | PostToolUse | Runs type checking after edits |
| `console-log-warn` | PostToolUse | Warns about debug statements |
| `mcp-health` | PostToolUseFailure | Checks MCP server health on failure |
| `save-state` | PreCompact | Saves session state before compacting |
| `load-context` | SessionStart | Loads project context on session start |
| `console-log-check` | Stop | Final check for debug statements |
| `session-end` | Stop | Session cleanup |
| `lifecycle-marker` | SessionEnd | Marks session lifecycle events |

**How it works:**
1. Enable in `.octopus.yml`:
   ```yaml
   hooks: true
   ```
2. Run `./octopus/setup.sh`
3. Hooks are injected into `.claude/settings.json`

**Disable specific hooks:**
```bash
OCTOPUS_DISABLED_HOOKS=auto-format,typecheck ./octopus/setup.sh
```

### Roles

Agent personas that combine a responsibility definition with your project context. Each role generates a specialized agent.

**Available roles:** `product-manager`, `backend-specialist`, `frontend-specialist`, `tech-writer`

**How it works:**
1. Add roles to `.octopus.yml`:
   ```yaml
   roles:
     - product-manager
     - backend-specialist
   ```
2. Optionally configure knowledge modules (see [Knowledge](#knowledge)) — their content is injected as project context into each role
3. Run `./octopus/setup.sh`
4. **Claude Code**: each role becomes a native agent file in `.claude/agents/<role>.md` with YAML frontmatter (name, model, color)
5. **Other agents**: roles are appended as sections to the agent's output file

**The role template** contains a `{{PROJECT_CONTEXT}}` placeholder that gets replaced with assembled knowledge module content. The `_base.md` file provides shared guidelines appended to all roles.

**Adding custom roles:**
1. Create `octopus/roles/<name>.md` with YAML frontmatter and `{{PROJECT_CONTEXT}}` placeholder
2. Add `- <name>` to the `roles:` list in `.octopus.yml`

### Knowledge

Modular domain knowledge that agents can load on demand — confirmed facts, hypotheses under investigation, and promoted rules. Each domain lives in its own folder under `knowledge/` and follows a structured format.

**How it works:**
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
       - authentication
     roles:
       backend-specialist:
         - domain
         - architecture
       product-manager:
         - domain
   ```
2. Run `./octopus/setup.sh`
3. **Claude Code**: `knowledge/` is symlinked to `.claude/knowledge/` — agents load modules on demand
4. **Other agents**: knowledge content is assembled per-role and inlined into the `{{PROJECT_CONTEXT}}` placeholder

**Custom directory:** By default, modules live in `knowledge/`. Use `knowledge_dir:` to change the location:
```yaml
knowledge_dir: docs/ai   # modules will be read from docs/ai/ instead of knowledge/
knowledge: true
```

**Auto-generated index:** `setup.sh` creates `<knowledge_dir>/INDEX.md` — a routing table listing every active module with file counts. Agents consult this first to find relevant domain context.

**Creating a knowledge module:**
```bash
cp -r octopus/knowledge/_template knowledge/<domain>
# Edit the files inside knowledge/<domain>/
```

Each module contains:
- `knowledge.md` — confirmed facts and anti-patterns
- `hypotheses.md` — under-investigation observations (promoted to rules after 5 confirmations)
- `rules.md` — auto-applied rules promoted from hypotheses

### Commands

Custom slash commands that map to CLI operations. Useful for database management, dev server control, tunnels, and other project-specific tasks.

**How it works:**
1. Add commands to `.octopus.yml`:
   ```yaml
   commands:
     - name: db-reset
       description: Reset the database
       run: make db-reset
     - name: api-start
       description: Start the API container
       run: make api-start
   ```
2. Run `./octopus/setup.sh`
3. **Claude Code**: each command becomes a file at `.claude/commands/octopus:<name>.md` — usable as `/octopus:<name>` slash commands
4. **Other agents**: commands are listed as a reference section in the agent's output file

### Feature Lifecycle

A complete documentation lifecycle system that combines a decision framework skill, document bootstrap commands, a documentation-focused role, and reusable templates.

**Decision matrix (what to create):**
- All factors low (single team, low uncertainty, reversible, < 1 week) → lightweight Spec
- Any factor high → detailed Spec via `/octopus:doc-spec`
- 2+ factors high → RFC first via `/octopus:doc-rfc`, then Spec after approval
- Any architectural decision during work → ADR via `/octopus:doc-adr`

**Available commands:**
- `/octopus:doc-rfc` — create RFC from template (`docs/rfcs/YYYY-MM-DD-<slug>.md`)
- `/octopus:doc-spec` — create Spec from template (`docs/specs/<slug>.md`)
- `/octopus:doc-adr` — create numbered ADR from template (`docs/adrs/NNN-<slug>.md`)

**Role:** `tech-writer`  
Use this role when you need documentation-only execution: pre-implementation RFC/spec drafting, post-implementation ADR/spec deviation reconciliation, knowledge capture, and changelog updates.

**Templates:**
- `templates/rfc.md`
- `templates/spec.md`
- `templates/adr.md`
- `templates/impl-prompt.md`

**Skill integration:**
- `feature-lifecycle` orchestrates when each artifact is needed
- `adr` provides ADR format and decision-record guidance
- `continuous-learning` captures post-implementation knowledge in `knowledge/<domain>/`

### MCP Servers

External tool integrations (Notion, GitHub, Slack, PostgreSQL) configured from a single source.

**Available servers:** `notion`, `github`, `slack`, `postgres`

**How it works:**
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
3. Run `./octopus/setup.sh`
4. Delivery varies per agent (see Capability Matrix):
   - **Claude Code**: merged into `.claude/settings.json` under `mcpServers`
   - **Copilot**: `.vscode/mcp.json` + `~/.copilot/mcp-config.json`
   - **Codex**: `codex mcp add` CLI commands

**Adding custom MCP servers:**
1. Create `octopus/mcp/<name>.json` following the template in `mcp/_template.json`
2. Use `${VAR_NAME}` for secrets — they'll be read from `.env.octopus`
3. Add `- <name>` to the `mcp:` list in `.octopus.yml`

### Workflow

PR and branch automation commands powered by GitHub CLI (`gh`).

**Available workflow commands:**

| Command | What it does |
|---|---|
| `/octopus:branch-create` | Create a branch following naming conventions |
| `/octopus:pr-open` | Push branch and create a PR |
| `/octopus:pr-review` | Request review from configured reviewers |
| `/octopus:pr-comments` | Handle PR comment feedback |
| `/octopus:pr-merge` | Merge a PR |
| `/octopus:codereview` | Run a code review workflow |
| `/octopus:dev-flow` | Full development flow |
| `/octopus:doc-rfc` | Bootstrap an RFC document from template |
| `/octopus:doc-spec` | Bootstrap a spec document from template |
| `/octopus:doc-adr` | Bootstrap an ADR document from template |
| `/octopus:release` | Create a release, sync version docs, and tag it |
| `/octopus:update` | Update Octopus to a newer version |

**How it works:**
1. Enable in `.octopus.yml`:
   ```yaml
   workflow: true
   reviewers:
     - github-username
   ```
2. Ensure `gh` is installed and authenticated: `gh auth login`
3. Run `./octopus/setup.sh`
4. **Claude Code**: commands become individual slash command files
5. **Other agents**: commands are listed with CLI invocation instructions

## Agent Manifests

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

### Adding a New Agent

1. Create `octopus/agents/<name>/`
2. Add `manifest.yml` declaring capabilities (copy from an existing agent and adjust)
3. Add `header.md` with tool-specific instructions (limitations, format preferences)
4. Add `- <name>` to `.octopus.yml` agents list
5. Run `./octopus/setup.sh`

No changes to `setup.sh` needed — the manifest drives all behavior.

## Project Structure

```
octopus/
├── agents/                 # Per-agent configuration
│   ├── claude/             # manifest.yml + CLAUDE.md template + settings.json
│   ├── copilot/            # manifest.yml + header.md
│   ├── codex/              # manifest.yml + header.md
│   ├── antigravity/        # manifest.yml + header.md
│   └── opencode/           # manifest.yml + header.md
├── core/                   # Universal standards
│   ├── guidelines.md       # Coding principles
│   ├── architecture.md     # System architecture standards
│   ├── commit-conventions.md
│   ├── pr-workflow.md
│   └── task-management.md
├── rules/                  # Language-specific coding rules
│   ├── common/             # Always included (coding-style, patterns, security, testing, quality)
│   ├── csharp/             # C#/.NET rules
│   ├── typescript/         # TypeScript/React/Next.js rules
│   └── python/             # Python rules
├── skills/                 # Reusable AI capabilities (each has SKILL.md)
│   ├── adr/
│   ├── dotnet/             # .NET backend patterns (Minimal APIs, EF Core, MediatR, etc.)
│   ├── feature-lifecycle/  # Documentation decision framework
│   ├── continuous-learning/
│   └── ...
├── hooks/                  # Claude Code lifecycle hooks + hooks.json
├── knowledge/
│   ├── _template/          # Continuous learning domain bootstrap
│   └── _examples/          # Reference examples
├── roles/
│   ├── _base.md
│   ├── backend-specialist.md
│   ├── frontend-specialist.md
│   ├── product-manager.md
│   └── tech-writer.md      # Documentation lifecycle agent
├── commands/
│   ├── doc-rfc.md          # Bootstrap RFC from template
│   ├── doc-spec.md         # Bootstrap Spec from template
│   ├── doc-adr.md          # Bootstrap ADR from template
│   ├── pr-open.md
│   └── ...
├── templates/              # Document templates (RFC, Spec, ADR, Impl Prompt)
├── mcp/                    # MCP server configs (JSON, env var substitution)
├── cli/                    # CLI utilities for workflow automation
├── setup.sh                # Main generation script
└── .octopus.example.yml    # Configuration template
```

In your repo root (alongside the submodule):

```
├── .octopus/               # (optional) project-level Octopus overrides
│   └── rules/
│       └── common/
│           └── language.local.md   # distributed by setup.sh to all configured agents
```

## Troubleshooting

**`syntax error` or associative arrays not working**
Ensure you're running Bash 4+. macOS ships with Bash 3 — install a newer version with `brew install bash` and run `bash ./octopus/setup.sh` explicitly.

**`command not found: python3`**
Python 3 is required for JSON merging (MCP injection and hooks). Install with `brew install python3` (macOS) or `sudo apt install python3` (Linux).

**`gh: command not found` when `workflow: true`**
Install GitHub CLI from https://cli.github.com, then authenticate: `gh auth login`.

**Symlinks not created (rules/skills missing from `.claude/`)**
Always run `setup.sh` from your repo root, not from inside the `octopus/` directory:
```bash
# Correct
./octopus/setup.sh

# Wrong — will fail to locate PROJECT_ROOT
cd octopus && ./setup.sh
```

**MCP environment variables not substituted**
Ensure `.env.octopus` exists in your repo root with the required variables before running `setup.sh`. Copy from the generated template: `cp .env.octopus.example .env.octopus`.

**Hooks not injected into `.claude/settings.json`**
Requires Python 3 for JSON merging. Also verify `hooks: true` is set in `.octopus.yml`. Check for Python with `python3 --version`.

## Contributing

Contributions are welcome!

1. Fork the repo and create a branch following Octopus conventions: `feat/<description>`, `fix/<description>`, `docs/<description>`
2. Make your changes — follow patterns in existing agents, rules, and skills
3. Run the test suite before opening a PR:
   ```bash
   for t in tests/test_*.sh; do bash "$t"; done
   ```
4. Open a PR targeting `main`

**Extending Octopus:**
- **New agent**: Create `agents/<name>/manifest.yml` + `header.md` — no changes to `setup.sh` needed
- **New rule set**: Create `rules/<language>/` with `.md` files
- **New skill**: Create `skills/<name>/SKILL.md`
- **New MCP server**: Create `mcp/<name>.json` following `mcp/_template.json`

Please open an issue first for large changes or new features.

## Requirements

- Bash 4+
- Python 3 (for JSON merging in MCP and hooks injection)
- Git (with submodule support)
- `gh` (GitHub CLI) >= 2.0 — only if `workflow: true`

## License

MIT — see [LICENSE](./LICENSE) for details.
