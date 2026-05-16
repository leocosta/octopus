# Quality Checklist

> **Extend-only:** create `quality.local.md` in this directory to add checks. Removing Octopus defaults via a local file is not recommended.

## Before Committing
- Never use `--no-verify` — always execute pre-commit hooks
- Check for hardcoded secrets (API keys, JWT tokens, passwords, AWS keys, Slack/GitHub/Stripe/SendGrid tokens) — use environment variables
- Review all changes before pushing

## After Editing Files
- Run the project formatter:
  - TypeScript/JavaScript/JSON: biome or prettier
  - C#: `dotnet format`
  - Python: ruff or black
- Run the type checker:
  - TypeScript: `tsc --noEmit`
  - C#: `dotnet build --no-restore`
  - Python: mypy or pyright

## Debug Statements
- Do not leave `console.log` (JS/TS) or `print()` (Python) in production code
- Before finalizing any task, check all modified files for debug statements and remove them

## Documentation
- Place design docs (*-design.md, *-spec.md, *-plan.md) in the `docs/` directory
