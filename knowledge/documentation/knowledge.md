# Documentation Knowledge

## Confirmed Facts

- [FACT-001] Specialized roles must be reviewed against their full operating ecosystem, not only their prompt.
  - Evidence: `roles/`, `skills/`, `commands/`, `templates/`, and `setup.sh` were all involved in the `tech-writer` audit on 2026-04-03.
  - Date: 2026-04-03

- [FACT-002] Inconsistent documentation paths create operational drift for agents and humans.
  - Evidence: `docs/adr/` in `skills/adr/SKILL.md` conflicted with `docs/adrs/` used by commands, README, and role guidance before the 2026-04-03 alignment.
  - Date: 2026-04-03

- [FACT-003] Role frontmatter intended for native agent files must use the target agent's strict schema, especially for color fields.
  - Evidence: OpenCode rejected generated role files when `roles/*.md` used named colors such as `purple`, `green`, and `orange`; normalizing to hex in `setup.sh` and updating the existing role files resolved the `Invalid hex color format color` failure on 2026-04-03.
  - Date: 2026-04-03

- [FACT-004] Role documentation becomes much more actionable when it includes an end-to-end operating example tied to generated artifacts and real project commands.
  - Evidence: The README's `tech-writer` section was expanded on 2026-04-03 with `.claude/agents/tech-writer.md`, `/octopus:doc-*` commands, prompt templates, and execution guidance after a user specifically requested concrete operating instructions for Claude Code.
  - Date: 2026-04-03

- [FACT-005] Operational role docs are stronger when they include pre-flight checks, expected outputs, and troubleshooting guidance instead of only happy-path examples.
  - Evidence: The `tech-writer` README guidance was further expanded on 2026-04-03 with session prep, success criteria, and failure recovery steps to make Claude Code usage reproducible for real teams.
  - Date: 2026-04-03

- [FACT-006] Operational shell entrypoints documented for direct execution must keep their executable bit to avoid workflow regressions.
  - Evidence: `setup.sh` and `tests/test_parse_yaml.sh` lost mode `100755` during the 2026-04-03 documentation-role changes; restoring the executable bit was necessary because the README and test workflow rely on direct script execution such as `./setup.sh`.
  - Date: 2026-04-03

## Anti-Patterns

- [ANTI-001] Defining a documentation role without an evidence hierarchy.
  - Reason: it encourages plausible but unverified writing when code, tests, and specs disagree.

- [ANTI-002] Letting workflow docs promise generated artifacts that runtime setup does not always create.
  - Reason: it weakens trust in the documentation system and makes agent behavior inconsistent.
