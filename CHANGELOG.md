# Changelog

All notable changes to this project will be documented in this file.

## [0.9.1] - 2026-03-31

🐛 Fixes `PROJECT_ROOT` detection when octopus is used as a submodule inside a project that also has `.octopus.yml`. Previously, the self-setup condition was incorrectly triggered because octopus's own `.octopus.yml` exists in `OCTOPUS_DIR`, causing all generated files (commands, rules, agents) to be written to `<project>/octopus/.claude/` instead of `<project>/.claude/`. The fix checks the parent directory for `.octopus.yml` first (submodule mode), falling back to self-setup only when octopus is the root project.

## [0.9.0] - 2026-03-30

✨ This release introduces **Language Rules** (RM-005), making Octopus aware of each project's language requirements. The `rules/common/language.md` rule has been reworked from a static "English only" directive into a behavioral detection rule: the AI now reads project context — existing documentation, commit history, and translation files — to infer the correct language for each artifact type, never defaulting to the conversation language.

✨ For projects with explicit requirements, a new `language:` field is available in `.octopus.yml`, supporting both short form (`language: pt-br`) and per-scope form (`docs:`, `code:`, `ui:`). `setup.sh` automatically generates a `language.local.md` in each configured CA's rules directory, eliminating duplication. For more complex cases, the `.octopus/` directory serves as a single source of truth for project-level overrides — `setup.sh` distributes any `.local.md` file found there to all configured agents.

♻️ Internally, rule delivery for native-rules agents (Claude) was refactored from a directory symlink to **per-file symlinks**, enabling the generated `language.local.md` to coexist alongside the original Octopus rule files.

📝 Documentation updated: capability matrix, new "Language Configuration" section in the README, RM-005 spec, and roadmap.

🧪 Integration tests updated to reflect the new per-file symlink structure.

## [0.8.0] - 2026-03-30

This release introduces four new manifest fields for the Claude agent, all inspired by Boris Cherny's Claude Code tips.

✨ The `.octopus.yml` manifest received four new configuration fields: **`permissions:`** defines allow/deny lists for pre-approved commands, with per-language defaults via `permissions: true`; **`effortLevel:`** sets the project-level reasoning depth (`low | medium | high | max`), removing the need to configure it manually each session; **`autoMode:`** enables automatic permission mode (`permissionMode: auto`), a safer alternative to `--dangerously-skip-permissions`; and **`memory:`** with `auto` and `dream` subfields configures persistent memory and periodic memory consolidation via a subagent.

✨ A new **PostCompact hook** (`hooks/post-compact/reload-context.sh`) re-injects working context after session compaction by reading the state saved by the PreCompact hook and restoring the current branch, timestamp, and modified files.

✨ The **`## Claude-Specific Behavior`** section in all 5 agent templates has been filled with three recommended practices: updating the project instructions file after every correction, planning before complex tasks, and running `/simplify` for code quality review after changes.

🔧 Templates, commands, and skills were translated to English to standardize the language across all repository artifacts.

## [0.7.0] - 2026-03-29

✨ The feature-lifecycle gained a **Phase 0: Research & Roadmap**, with the `/octopus:doc-research` command for interactive brainstorming sessions that generate tracked items (`RM-NNN`) in `docs/roadmap.md`. Research documents are persisted under `docs/research/` for future reference. The CLAUDE.md template was updated with a Roadmap & Backlog section, and the `/octopus:docs` command (a Context7 wrapper with no Octopus-specific logic) was removed.

## [0.6.0] - 2026-03-29

♻️ This release removes legacy features that were no longer needed. The `.env` file was renamed to `.env.octopus` to avoid naming collisions in projects that use Octopus as a submodule. Support for `.octopus-context.md` was removed in favor of knowledge modules, which offer a more modular and structured approach to project context. The `stacks/` directory and automatic migration logic were eliminated — projects should use `rules:` directly in `.octopus.yml`. Documentation templates (RFC, Spec, ADR, Impl Prompt) were moved from `knowledge/_templates/` to a top-level `templates/` directory, making their purpose clearer.

## [0.5.0] - 2026-03-29

✨ A new `/octopus:update` command was added, allowing agents to update the Octopus submodule to newer versions in a guided and automated way. The `dev-flow` skill was extended with a Step 7 cleanup phase ♻️ that removes the git worktree and deletes local and remote branches after a successful merge. 📝 The README and example files were also updated to prepare the project for community release.

## [0.4.0] - 2026-03-29

✨ Phase 1 of Knowledge Modules integration. Knowledge is now a first-class
concept in the Octopus pipeline — modules are discovered from the project's
`knowledge/` directory (or a custom path via `knowledge_dir:`), assembled
per-role with optional role mapping, and delivered through the manifest-driven
architecture. The `knowledge:` key in `.octopus.yml` supports three formats:
boolean auto-discover, explicit module list, and full config with per-role
mapping. Backward compatibility with `.octopus-context.md` is fully preserved.
The `INDEX.md` is now auto-generated by `setup.sh`. Claude Code receives a
symlink to `knowledge/` for progressive context discovery; concatenate agents
receive inlined knowledge in their role sections.

🐛 Fixed slash command descriptions not appearing in Claude Code and other code
assistants — a leading blank line before the YAML frontmatter in generated
command files was preventing the description from being parsed. Custom commands
also now use YAML frontmatter instead of plain text.

🔧 The `branch-create` skill now infers a branch name from context and proposes
it for confirmation, instead of asking open-ended questions.

🧪 Added `tests/test_knowledge.sh` with 9 tests covering all knowledge delivery
scenarios.

## [0.3.0] - 2026-03-28

✨ Feature Lifecycle Documentation System — a complete documentation workflow
integrated into the Octopus pipeline. Includes a new `feature-lifecycle` skill
that guides agents through the right documentation for each phase of a feature
(RFC → Spec → ADR → Knowledge). Three new slash commands (`/octopus:doc-rfc`,
`/octopus:doc-spec`, `/octopus:doc-adr`) bootstrap documents from templates.
A new `tech-writer` role provides a dedicated documentation agent that can
produce post-implementation documentation, spec updates, and knowledge capture.
Document templates live in `knowledge/_templates/` (RFC, Spec, ADR,
Implementation Prompt).

## [0.2.1] - 2026-03-28

♻️ This release migrates the agent configuration from `kilocode` to `opencode`, modernizing the project structure and aligning with current naming conventions. The legacy kilocode agent was removed and replaced with a new opencode agent that supports full native capabilities (rules, skills, hooks, commands, agents, and MCP). Configuration files and documentation were updated to reflect the change, including `.gitignore`, `.octopus.yml`, and `README.md`. Additionally, the PR creation workflow (`pr-open.sh`) was enhanced ✨ to automatically generate rich, context-aware PR bodies with emoji-styled summaries, commit narratives, and file change categorization.

## [0.2.0] - 2026-03-28

✨ This release introduces the Continuous Learning system, a knowledge management framework that enables capturing insights, testing hypotheses, and promoting confirmed patterns to rules. The system includes templates and examples for structuring project knowledge across teams. Additionally, a submodule URL in the README was corrected 🐛 to ensure proper repository linking.

## [0.1.0] - 2026-03-23

✨ This is the initial release of the **Octopus** project. The base repository structure was added, including directory layout, placeholders for coding guidelines, architecture, commit conventions, PR workflow, and task management. Configurations for agents (Claude Code, Copilot, Codex, among others), MCP servers (Notion, GitHub, Slack, Postgres), and configuration templates such as `.octopus.example.yml` and `.env.example` were also included. The setup script (`setup.sh`) was updated and new configuration files were added.
