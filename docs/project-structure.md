# Project Structure

```
octopus/
├── agents/                 # Per-agent configuration
│   ├── claude/             # manifest.yml + CLAUDE.md template + settings.json
│   ├── copilot/            # manifest.yml + header.md
│   ├── codex/              # manifest.yml + header.md
│   ├── gemini/             # manifest.yml + header.md
│   └── opencode/           # manifest.yml + header.md
├── core/                   # Universal standards
│   ├── guidelines.md
│   ├── architecture.md
│   ├── commit-conventions.md
│   ├── pr-workflow.md
│   └── task-management.md
├── rules/                  # Language-specific coding rules
│   ├── common/             # Always included (coding-style, patterns, security, testing, quality)
│   ├── csharp/
│   ├── typescript/
│   └── python/
├── skills/                 # Reusable AI capabilities (each has SKILL.md)
│   ├── adr/
│   ├── dotnet/
│   ├── feature-lifecycle/
│   ├── continuous-learning/
│   └── ...
├── hooks/                  # Claude Code lifecycle hooks + hooks.json
├── knowledge/
│   ├── _template/          # Domain bootstrap template
│   └── _examples/          # Reference examples
├── roles/
│   ├── _base.md
│   ├── backend-specialist.md
│   ├── frontend-specialist.md
│   ├── product-manager.md
│   ├── social-media.md
│   └── tech-writer.md
├── scripts/
│   └── x_post.py           # Preview and publish text posts to X
├── commands/               # Slash command definitions
│   ├── doc-rfc.md
│   ├── doc-spec.md
│   ├── doc-adr.md
│   ├── pr-open.md
│   └── ...
├── templates/              # Document templates (RFC, Spec, ADR, Impl Prompt)
├── mcp/                    # MCP server configs (JSON, env var substitution)
├── cli/                    # CLI utilities for workflow automation
├── bin/                    # Global CLI shim (octopus)
├── install.sh              # Unix/macOS installer
├── install.ps1             # Windows PowerShell installer
├── setup.sh                # Main configuration generator
└── .octopus.example.yml    # Configuration template
```

In your repo root:

```
├── .octopus.yml            # Your configuration
├── .octopus/               # (optional) project-level overrides
│   └── rules/
│       └── common/
│           └── language.local.md
└── .env.octopus            # MCP server credentials (not committed)
```
